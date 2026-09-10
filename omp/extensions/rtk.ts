/**
 * RTK extension for oh-my-pi — rewrites bash commands to use `rtk` for token savings.
 *
 * Adapted from rtk-ai/rtk `hooks/pi/rtk.ts` for omp's extension runtime:
 *   - omp's `tool_call` contract is return-based: a handler revises the executed
 *     command by RETURNING `{ input }`, not by mutating `event.input` in place
 *     (see docs/hooks.md — the returned input replaces the raw execution input,
 *     not the normalized `event.input` view).
 *   - rtk availability is probed lazily on first bash call (cached), so no
 *     `pi.exec` runs during extension load.
 *
 * All rewrite logic lives in `rtk rewrite` (single source of truth in rtk's Rust
 * registry). Exit-code contract:
 *   0 + stdout   rewrite found      → replace command
 *   3 + stdout   rewrite (advisory) → replace command
 *   1            no rtk equivalent  → pass through unchanged
 *
 * Requires: rtk >= 0.23.0 in PATH. Disable at runtime with RTK_DISABLED=1, or
 * permanently via `disabledExtensions: [extension-module:rtk]` in config.yml.
 */

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const REWRITE_TIMEOUT_MS = 2_000;
const MIN_SUPPORTED_RTK_MINOR = 23;

export default function (pi: ExtensionAPI) {
  pi.setLabel?.("RTK token saver");

  // undefined = not yet probed; true/false = cached probe result.
  let enabled: boolean | undefined;

  pi.on("tool_call", async (event, ctx) => {
    try {
      if (event.toolName !== "bash") return;

      const input = event.input;
      if (!input || typeof input !== "object" || !("command" in input)) return;
      const cmd = input.command;
      if (typeof cmd !== "string" || cmd.trim() === "") return;

      if (cmd.startsWith("rtk ")) return;
      if (process.env.RTK_DISABLED === "1") return;

      // Probe rtk once and cache the verdict; a failed probe stays disabled.
      if (enabled === undefined) {
        enabled = false;
        const ver = await pi.exec("rtk", ["--version"], { timeout: REWRITE_TIMEOUT_MS });
        if (ver.code !== 0) {
          pi.logger?.warn?.("[rtk] binary not found in PATH — extension inert");
        } else {
          const m = ver.stdout.match(/(\d+)\.(\d+)\.(\d+)/);
          const tooOld =
            m !== null && parseInt(m[1], 10) === 0 && parseInt(m[2], 10) < MIN_SUPPORTED_RTK_MINOR;
          if (tooOld) {
            pi.logger?.warn?.(
              `[rtk] ${ver.stdout.trim()} is too old (need >= 0.23.0) — extension inert`,
            );
          } else {
            enabled = true;
          }
        }
      }
      if (!enabled) return;

      let signal: AbortSignal | undefined;
      if (ctx && "signal" in ctx && ctx.signal instanceof AbortSignal) {
        signal = ctx.signal;
      }

      // Delegate to `rtk rewrite`: code 0/3 + stdout = rewrite, code 1 = pass through.
      const r = await pi.exec("rtk", ["rewrite", cmd], { timeout: REWRITE_TIMEOUT_MS, signal });
      if (r.killed || (r.code !== 0 && r.code !== 3)) return;
      const rewritten = r.stdout.trim();
      if (rewritten && rewritten !== cmd) {
        // omp applies a RETURNED input as the raw execution input.
        return { input: { ...input, command: rewritten } };
      }
    } catch (err) {
      // Fail open: never block a command on an unexpected error.
      pi.logger?.warn?.("[rtk] tool_call handler error; passing through", err);
      return;
    }
  });
}
