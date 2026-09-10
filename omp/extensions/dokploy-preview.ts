/**
 * Dokploy preview indicator for oh-my-pi.
 *
 * omp's built-in `pr` status-line segment links the pull request; this adds the
 * other half of the Claude Code line — the Dokploy preview deployment built for
 * that pull request, its build state, and its URL as an OSC 8 hyperlink.
 *
 * Why a widget rather than a status-line segment:
 *   - `statusLine.leftSegments` is a closed union of built-in ids, so an
 *     extension cannot contribute one.
 *   - `ctx.ui.setStatus()` (the `status` segment) runs its text through
 *     `sanitizeStatusText`, which replaces every C0/C1 byte with a space. The
 *     escape that carries the link would not survive, leaving the state text
 *     with nothing clickable behind it.
 *   - `ctx.ui.setWidget()` renders the string verbatim, so the hyperlink lands
 *     intact on its own row under the composer.
 *
 * All the Dokploy knowledge lives in `dokploy-previews` (dotfiles/scripts):
 * `segment` reads its cache, keys off the checked-out branch, prints nothing
 * when there is no preview to report, and never fetches inline — a cold or
 * stale cache only spawns a detached refresh that lands on a later poll. That
 * makes the exec below cheap enough to repeat on a timer.
 *
 * Needs `tui.hyperlinks` to be `auto` on a terminal that advertises OSC 8, or
 * `always` (see omp/config.yml — tmux + truecolor detects as `trueColor`, which
 * omp treats as link-less, so this setup forces it on).
 */

import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

const WIDGET_KEY = "dokploy-preview";
const SCRIPT = "dokploy-previews";
/** Cheap enough to poll: the script serves its cache and refreshes behind it. */
const POLL_MS = 10_000;
const EXEC_TIMEOUT_MS = 5_000;

export default function (pi: ExtensionAPI) {
  pi.setLabel?.("Dokploy preview");

  // The rendered line currently on screen, so an unchanged poll costs no
  // repaint. `undefined` means no widget is mounted.
  let shown: string | undefined;
  let inFlight = false;
  // Set once the script turns out to be unusable (not in PATH). Retrying every
  // poll for the lifetime of the session would spend a process each time to
  // learn the same thing.
  let disabled = false;

  async function refresh(ctx: ExtensionContext): Promise<void> {
    if (disabled || inFlight || !ctx.hasUI) return;
    inFlight = true;
    try {
      const result = await pi.exec(SCRIPT, ["segment"], {
        cwd: ctx.cwd,
        timeout: EXEC_TIMEOUT_MS,
      });
      if (result.killed) return;
      // Exit 127 is the shell's "command not found"; a real failure (bad repo,
      // unreadable cache) is a transient the next poll may well survive, so
      // only a missing script disables the extension.
      if (result.code === 127) {
        disabled = true;
        pi.logger?.warn?.(`[dokploy-preview] ${SCRIPT} not found in PATH — extension inert`);
        return;
      }
      const line = result.code === 0 ? result.stdout.replace(/\r?\n$/, "") : "";
      const next = line.length > 0 ? line : undefined;
      if (next === shown) return;
      shown = next;
      ctx.ui.setWidget(WIDGET_KEY, next ? [next] : undefined, { placement: "belowEditor" });
    } catch (error) {
      // `exec` rejects instead of exiting 127 when the binary cannot be spawned
      // at all. Everything else stays a transient.
      const code = (error as { code?: string } | undefined)?.code;
      if (code === "ENOENT") {
        disabled = true;
        pi.logger?.warn?.(`[dokploy-preview] cannot spawn ${SCRIPT} — extension inert`);
        return;
      }
      pi.logger?.warn?.("[dokploy-preview] refresh failed", error);
    } finally {
      inFlight = false;
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    await refresh(ctx);
    // Managed timer: unref'd, cleared on shutdown, and a throw inside is
    // contained instead of taking the session down with it.
    ctx.setInterval(() => {
      void refresh(ctx);
    }, POLL_MS);
  });

  // A turn that opened the pull request or pushed to it changes the answer well
  // before the next poll would.
  pi.on("agent_end", async (_event, ctx) => {
    await refresh(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (shown === undefined) return;
    shown = undefined;
    ctx.ui.setWidget(WIDGET_KEY, undefined, { placement: "belowEditor" });
  });
}
