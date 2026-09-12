# GTD assistant launcher: spawn fx anywhere with the assistant prompt injected.

const gtd_prompt = "dotfiles/fx/gtd/assistant-prompt.md"

export def main [
  --model: string  # override the model for this session, e.g. minimax/minimax-m2.5
  --continue (-c)  # resume this workspace's latest session instead of spawning fresh
] {
  if $model != null {
    # Per-process override; fx never writes this back to settings.
    $env.FX_MODEL = $model
  }
  let prompt_path = ($env.HOME | path join $gtd_prompt)
  if not ($prompt_path | path exists) {
    error make { msg: $"Assistant prompt not found: ($prompt_path)" }
  }
  if $continue {
    fx resume last
  } else {
    # Seed the session with the assistant prompt, then drop into it.
    open $prompt_path | fx ask
    fx resume last
  }
}
