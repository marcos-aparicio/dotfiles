/**
 * Skill picker for oh-my-pi.
 *
 * Ctrl+Y (or /skills) opens a filter-as-you-type list of every loaded skill
 * and drops `/skill:<name>` into the composer. Press Enter to invoke it, or type
 * arguments first. Any draft already in the composer is carried over as the
 * skill's arguments.
 */

import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

// Terminals collapse Ctrl+Shift+<letter> to Ctrl+<letter>, Ctrl+H/I/M/[ are
// Backspace/Tab/Enter/Esc, tmux's vim-tmux-navigator eats Ctrl+H/J/K/L and Ctrl+\,
// and Ctrl+Alt+<letter> never arrives here. Ctrl+Y is free once
// `tui.editor.yank: []` in keybindings.yml releases it.
const SHORTCUTS = ["ctrl+y"];
const SKILL_PREFIX = "skill:";

async function pickSkill(pi: ExtensionAPI, ctx: ExtensionContext) {
  if (!ctx.hasUI) {
    return;
  }

  const skills = pi.getCommands().filter((command) => command.source === "skill");
  if (skills.length === 0) {
    ctx.ui.notify("No skills are loaded in this session.", "warning");
    return;
  }

  const options = skills
    .map((command) => ({
      label: command.name.slice(SKILL_PREFIX.length),
      description: command.description,
    }))
    .sort((a, b) => a.label.localeCompare(b.label));

  const picked = await ctx.ui.select(`Invoke a skill (${options.length})`, options);
  if (!picked) {
    return;
  }

  const draft = ctx.ui.getEditorText().trim();
  ctx.ui.setEditorText(draft ? `/${SKILL_PREFIX}${picked} ${draft}` : `/${SKILL_PREFIX}${picked} `);
}

export default function (pi: ExtensionAPI) {
  for (const shortcut of SHORTCUTS) {
    pi.registerShortcut(shortcut, {
      description: "Pick a skill to invoke",
      handler: async (ctx) => {
        await pickSkill(pi, ctx);
      },
    });
  }

  pi.registerCommand("skills", {
    description: "Pick a skill to invoke",
    handler: async (_args, ctx) => {
      await pickSkill(pi, ctx);
    },
  });
}
