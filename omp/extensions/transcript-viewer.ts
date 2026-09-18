/**
 * Read-only transcript viewer for oh-my-pi — Claude Code's "transcript mode".
 *
 * Ctrl+E (or /transcript) replays the current session full-screen on the
 * alternate screen: j/k and the arrows scroll by line, `/` searches, and `t`/`T`
 * turn tool calls and thinking blocks on and off. Esc or q closes, and nothing
 * can ever be rewound from here.
 *
 * ## Why it borrows the rewind selector
 *
 * omp exports no public "render persisted session entries" builder — the chat
 * transcript builder lives inside pi-tui and is not on any entry point. The one
 * public surface that renders session entries through the production transcript
 * pipeline is `RewindSelectorComponent` (the esc-esc rewind view), so the viewer
 * drives that and replaces its keymap and chrome.
 *
 * Two consequences:
 *
 *  - Scrolling and search need the component's viewport, which is private. The
 *    viewer takes it from `TranscriptBrowser.prototype.composeOutline`, wrapped
 *    only for the duration of its own `render()` call (so no other component in
 *    the process ever sees the patch). That hands over both the live ScrollView
 *    and the complete body line list — the search index.
 *  - Hiding tool calls or thinking changes what gets built, not what gets shown,
 *    so each toggle rebuilds the component. The transcript re-anchors to the
 *    last turn afterwards.
 *
 * Header and footer are plain ` text` rows in the host's frame (borders are
 * separate rows), so substituting them keeps every row exactly `width` cells.
 */

import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { RewindSelectorComponent, theme } from "@oh-my-pi/pi-coding-agent";
import type { SessionMessageEntry } from "@oh-my-pi/pi-coding-agent/session/session-entries";
import { type Component, matchesKey, ScrollView, TranscriptBrowser, truncateToWidth } from "@oh-my-pi/pi-tui";

// Ctrl+E, freed in keybindings.yml by narrowing `tui.editor.cursorLineEnd` to
// the End key. Alt chords are taken by the window manager, Ctrl+Shift collapses
// to plain Ctrl in this terminal, and omp reserves ctrl+c/d/z/k/p/l/o/t/g/q.
const SHORTCUTS = ["ctrl+e"];

/** Substrings identifying the borrowed component's own header and footer rows. */
const HEADER_MARK = "pick the point to continue from";
const FOOTER_MARK = "enter rewind";

/** CSI/OSC sequences, stripped before matching a search query against a row. */
const ANSI_PATTERN = /\u001b\[[\d;:?]*[ -/]*[@-~]|\u001b\][^\u0007\u001b]*(?:\u0007|\u001b\\)/g;

/** Rows kept above a search hit when jumping to it. */
const MATCH_CONTEXT_ROWS = 2;

/** Any C0 control byte or DEL — marks a chunk as a key sequence, not text. */
const CONTROL_CHARS = /[\u0000-\u001f\u007f]/;

/** Minimal shape of one rendered transcript column; see the file header. */
interface OutlineColumn {
	lines: string[];
}

/** `composeOutline` as the viewer uses it: pass through, keep the lines. */
type ComposeOutline = (this: unknown, options: unknown) => { column: OutlineColumn };

interface SearchState {
	query: string;
	/** True while the query is still being typed. */
	typing: boolean;
	/** Body-line indexes that matched, ascending. */
	matches: number[];
	/** True when `matches` predate the current transcript build. */
	stale: boolean;
	/** Index into `matches`, or -1 before the first jump. */
	current: number;
}

/**
 * Drop tool calls from a branch: both the `toolResult` entries and the
 * `toolCall` blocks that spawned them, so no half-rendered call is left behind.
 * Entries are copied, never mutated — they belong to the live session.
 */
function withoutToolCalls(entries: SessionMessageEntry[]): SessionMessageEntry[] {
	const kept: SessionMessageEntry[] = [];
	for (const entry of entries) {
		const message = entry.message;
		if (message.role === "toolResult") continue;
		if (message.role === "assistant" && Array.isArray(message.content)) {
			const content = message.content.filter((block) => block.type !== "toolCall");
			if (content.length === 0) continue;
			kept.push({ ...entry, message: { ...message, content } });
			continue;
		}
		kept.push(entry);
	}
	return kept;
}

class TranscriptViewerComponent implements Component {
	#inner: RewindSelectorComponent;
	#viewport: ScrollView | undefined;
	#bodyLines: readonly string[] = [];
	#search: SearchState | undefined;
	#showToolCalls = true;
	#showThinking = true;
	#lastInner: readonly string[] | undefined;
	#lastState: string | undefined;
	#lastRendered: readonly string[] | undefined;

	constructor(
		private readonly entries: SessionMessageEntry[],
		private readonly build: (entries: SessionMessageEntry[], showThinking: boolean) => RewindSelectorComponent,
		private readonly requestRender: () => void,
		private readonly close: () => void,
	) {
		this.#inner = this.#create();
	}

	#create(): RewindSelectorComponent {
		const entries = this.#showToolCalls ? this.entries : withoutToolCalls(this.entries);
		return this.build(entries, this.#showThinking);
	}

	/** Rebuild after a visibility toggle; the new transcript re-anchors itself. */
	#rebuild(): void {
		this.#inner.dispose();
		this.#inner = this.#create();
		this.#viewport = undefined;
		this.#bodyLines = [];
		this.#lastInner = undefined;
		this.#lastRendered = undefined;
		if (this.#search) this.#search = { ...this.#search, matches: [], stale: true, current: -1 };
		this.requestRender();
	}

	// =========================================================================
	// Input
	// =========================================================================

	handleInput(data: string): void {
		if (this.#search?.typing) {
			this.#handleSearchInput(data);
			return;
		}

		// A terminal can deliver several keystrokes (or a paste) in one chunk.
		// Viewer commands are single characters, so a printable run is replayed
		// character by character; search typing keeps the chunk as pasted text.
		if (data.length > 1 && !CONTROL_CHARS.test(data)) {
			for (const character of data) this.handleInput(character);
			return;
		}

		// Mouse wheel and Ctrl+O (expand tool output) stay the host's behavior.
		if (data.startsWith("\x1b[<") || matchesKey(data, "ctrl+o")) {
			this.#inner.handleInput(data);
			return;
		}

		if (data === "q") {
			this.close();
			return;
		}
		if (matchesKey(data, "escape")) {
			// Esc clears an active search first, then closes.
			if (this.#search) {
				this.#search = undefined;
				this.requestRender();
				return;
			}
			this.close();
			return;
		}

		// Read-only: no rewinding, no sideways message hops.
		if (matchesKey(data, "enter") || matchesKey(data, "return") || data === "\n" || data === "\r") return;
		if (matchesKey(data, "left") || matchesKey(data, "right")) return;

		if (data === "/") {
			this.#search = { query: "", typing: true, matches: [], stale: false, current: -1 };
			this.requestRender();
			return;
		}
		if (data === "n" || data === "N") {
			this.#jumpMatch(data === "n" ? 1 : -1);
			return;
		}
		if (data === "t") {
			this.#showToolCalls = !this.#showToolCalls;
			this.#rebuild();
			return;
		}
		if (data === "T") {
			this.#showThinking = !this.#showThinking;
			this.#rebuild();
			return;
		}

		this.#handleScroll(data);
	}

	#handleScroll(data: string): void {
		const viewport = this.#viewport;
		if (!viewport) return;
		const before = viewport.getScrollOffset();

		if (data === "j" || matchesKey(data, "down")) viewport.scroll(1);
		else if (data === "k" || matchesKey(data, "up")) viewport.scroll(-1);
		else if (data === " " || matchesKey(data, "pageDown")) viewport.page(1);
		else if (data === "b" || matchesKey(data, "pageUp")) viewport.page(-1);
		else if (data === "g" || matchesKey(data, "home")) viewport.scrollToTop();
		else if (data === "G" || matchesKey(data, "end")) viewport.scrollToBottom();
		else if (matchesKey(data, "shift+down")) viewport.scroll(5);
		else if (matchesKey(data, "shift+up")) viewport.scroll(-5);
		else return;

		if (viewport.getScrollOffset() !== before) this.requestRender();
	}

	#handleSearchInput(data: string): void {
		const search = this.#search;
		if (!search) return;

		if (matchesKey(data, "escape")) {
			this.#search = undefined;
			this.requestRender();
			return;
		}
		if (matchesKey(data, "enter") || matchesKey(data, "return") || data === "\n" || data === "\r") {
			this.#search = { ...search, typing: false };
			this.#jumpMatch(1);
			return;
		}
		if (data === "\x7f" || data === "\b") {
			this.#setQuery(search.query.slice(0, -1));
			return;
		}
		// Printable text only: ignore control bytes and escape sequences.
		if (data.startsWith("\x1b") || data.charCodeAt(0) < 0x20) return;
		this.#setQuery(search.query + data);
	}

	#setQuery(query: string): void {
		this.#search = { query, typing: true, matches: this.#findMatches(query), stale: false, current: -1 };
		this.requestRender();
	}

	#findMatches(query: string): number[] {
		if (query.length === 0) return [];
		const needle = query.toLowerCase();
		const matches: number[] = [];
		for (let index = 0; index < this.#bodyLines.length; index++) {
			const plain = this.#bodyLines[index]!.replace(ANSI_PATTERN, "");
			if (plain.toLowerCase().includes(needle)) matches.push(index);
		}
		return matches;
	}

	/** Move to the next/previous hit, starting from what is on screen. */
	#jumpMatch(direction: 1 | -1): void {
		const search = this.#search;
		const viewport = this.#viewport;
		if (!search || !viewport || search.query.length === 0) return;

		const matches = search.stale || search.matches.length === 0 ? this.#findMatches(search.query) : search.matches;
		if (matches.length === 0) {
			this.#search = { ...search, typing: false, matches, stale: false, current: -1 };
			this.requestRender();
			return;
		}

		let next: number;
		if (search.current >= 0) {
			next = (search.current + direction + matches.length) % matches.length;
		} else {
			// First jump: nearest hit at or after the current viewport position.
			const offset = viewport.getScrollOffset() + MATCH_CONTEXT_ROWS;
			const ahead = matches.findIndex((line) => line >= offset);
			next = direction === 1 ? (ahead === -1 ? 0 : ahead) : ahead <= 0 ? matches.length - 1 : ahead - 1;
		}

		viewport.setScrollOffset(Math.max(0, matches[next]! - MATCH_CONTEXT_ROWS));
		this.#search = { ...search, typing: false, matches, stale: false, current: next };
		this.requestRender();
	}

	// =========================================================================
	// Render
	// =========================================================================

	render(width: number): readonly string[] {
		const inner = this.#renderInner(width);

		// A toggle rebuilt the transcript, so old hit rows mean nothing. The
		// fresh body lines only exist after the render above, so re-index here.
		const previous = this.#search;
		if (previous?.stale && this.#bodyLines.length > 0) {
			this.#search = { ...previous, matches: this.#findMatches(previous.query), stale: false, current: -1 };
		}
		// The host returns the same array reference while nothing changed; keep
		// that contract so the renderer can still skip unchanged frames — but
		// only while the viewer's own chrome (search, toggles) is unchanged too.
		const search = this.#search;
		const state = [
			width,
			this.#showToolCalls,
			this.#showThinking,
			search?.query ?? "",
			search?.typing ?? false,
			search?.current ?? -1,
			search?.matches.length ?? 0,
		].join("\u0000");
		if (inner === this.#lastInner && state === this.#lastState && this.#lastRendered) return this.#lastRendered;

		const lines = [...inner];
		const query = this.#search?.query ?? "";
		for (let index = 0; index < lines.length; index++) {
			const line = lines[index]!;
			// Chrome rows are rebuilt exactly as the host builds its own: one
			// leading space, then the text clipped to the remaining width.
			const chrome = line.includes(HEADER_MARK)
				? this.#header()
				: line.includes(FOOTER_MARK)
					? this.#footer()
					: undefined;
			if (chrome !== undefined) {
				lines[index] = width > 0 ? ` ${truncateToWidth(chrome, width - 1)}` : "";
			} else if (query.length > 0) {
				lines[index] = highlight(line, query);
			}
		}

		this.#lastInner = inner;
		this.#lastState = state;
		this.#lastRendered = lines;
		return lines;
	}

	/**
	 * Render the borrowed component, capturing its viewport and full body lines.
	 * The prototype wrap lives only for this call.
	 */
	#renderInner(width: number): readonly string[] {
		// The typings that ship with the npm package lag the installed binary,
		// which is why this one host internal is reached structurally.
		const proto = TranscriptBrowser.prototype as unknown as { composeOutline: ComposeOutline };
		const original = proto.composeOutline;
		let browser: unknown;
		let body: readonly string[] | undefined;
		proto.composeOutline = function (options: unknown) {
			const result = original.call(this, options);
			browser = this;
			body = result.column?.lines;
			return result;
		};
		try {
			return this.#inner.render(width);
		} finally {
			proto.composeOutline = original;
			if (body) this.#bodyLines = body;
			const children = (browser as { debugChildren?: unknown[] } | undefined)?.debugChildren;
			const viewport = children?.find((child): child is ScrollView => child instanceof ScrollView);
			if (viewport) this.#viewport = viewport;
		}
	}

	#header(): string {
		const state = [
			`tools ${this.#showToolCalls ? "on" : "off"}`,
			`thinking ${this.#showThinking ? "on" : "off"}`,
		].join(theme.sep.dot);
		return `${theme.bold("Transcript")}${theme.sep.dot}${theme.fg("dim", `read-only${theme.sep.dot}${state}`)}`;
	}

	#footer(): string {
		const search = this.#search;
		if (search?.typing) {
			const count = search.query.length === 0 ? "" : `  ${search.matches.length} matches`;
			return `${theme.fg("accent", `/${search.query}`)}${theme.fg("dim", `▏${count}  enter jump  esc cancel`)}`;
		}
		if (search) {
			const position =
				search.matches.length === 0 ? "no matches" : `${search.current + 1}/${search.matches.length}`;
			return `${theme.fg("accent", `/${search.query}`)}${theme.fg("dim", `  ${position}  n/N next  esc clear`)}`;
		}
		return theme.fg(
			"dim",
			"j/k scroll  space/b page  g/G ends  / search  t tools  T thinking  ctrl+o expand  esc close",
		);
	}

	invalidate(): void {
		this.#inner.invalidate();
		this.#lastInner = undefined;
		this.#lastRendered = undefined;
	}

	dispose(): void {
		this.#inner.dispose();
	}
}

/**
 * Reverse-video the query inside an already-styled row. SGR 7/27 is zero-width
 * and leaves the surrounding colors intact, so the row keeps its exact width.
 * Hits split across escape sequences are left alone rather than mangled.
 */
function highlight(line: string, query: string): string {
	const haystack = line.toLowerCase();
	const needle = query.toLowerCase();
	let from = haystack.indexOf(needle);
	if (from === -1) return line;
	let out = "";
	let cursor = 0;
	while (from !== -1) {
		out += `${line.slice(cursor, from)}\x1b[7m${line.slice(from, from + query.length)}\x1b[27m`;
		cursor = from + query.length;
		from = haystack.indexOf(needle, cursor);
	}
	return out + line.slice(cursor);
}

async function openTranscript(ctx: ExtensionContext): Promise<void> {
	if (!ctx.hasUI) return;

	const entries = ctx.sessionManager
		.getBranch()
		.filter((entry): entry is SessionMessageEntry => entry.type === "message");
	if (entries.length === 0) {
		ctx.ui.notify("Nothing in this session's transcript yet.", "info");
		return;
	}

	await ctx.ui.custom<void>(
		(tui, _theme, _keybindings, done) => {
			const requestRender = () => tui.requestRender();
			return new TranscriptViewerComponent(
				entries,
				(visible, showThinking) =>
					new RewindSelectorComponent(visible, {
						ui: tui,
						cwd: ctx.cwd,
						hideThinkingBlock: () => !showThinking,
						requestRender,
						// Read-only viewer: a selection can never be committed.
						onSelect: () => {},
						onCancel: () => done(undefined),
					}),
				requestRender,
				() => done(undefined),
			);
		},
		{
			overlay: true,
			overlayOptions: {
				anchor: "bottom-center",
				width: "100%",
				maxHeight: "100%",
				margin: 0,
				fullscreen: true,
			},
		},
	);
}

export default function (pi: ExtensionAPI) {
	for (const shortcut of SHORTCUTS) {
		pi.registerShortcut(shortcut, {
			description: "Open the read-only transcript viewer",
			handler: async (ctx) => {
				await openTranscript(ctx);
			},
		});
	}

	pi.registerCommand("transcript", {
		description: "Open the read-only transcript viewer",
		handler: async (_args, ctx) => {
			await openTranscript(ctx);
		},
	});
}
