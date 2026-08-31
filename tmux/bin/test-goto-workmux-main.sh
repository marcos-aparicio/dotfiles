#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/tmux/bin/goto-workmux-main.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local needle=$1
  local haystack=$2
  grep -Fq -- "$needle" <<<"$haystack" || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local needle=$1
  local haystack=$2
  ! grep -Fq -- "$needle" <<<"$haystack" || fail "did not expect output to contain: $needle"
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/project"

cat >"$tmp_dir/bin/workmux" <<'EOF'
#!/usr/bin/env bash
printf '[{"path":"%s","is_main":true}]\n' "$TEST_MAIN_PATH"
EOF

cat >"$tmp_dir/bin/sesh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_SESH_LOG"
case "$TEST_SESH_MODE:$1:$2" in
  tmux:list:-t)
    printf '[{"Src":"tmux","Name":"project","Path":"%s"}]\n' "$TEST_MAIN_PATH"
    ;;
  tmux:list:-c|tmux:list:--json)
    printf '[]\n'
    ;;
  config-fallback:list:-t)
    printf '[]\n'
    ;;
  config-fallback:list:-c)
    printf '[{"Src":"config","Name":"project-config","Path":"%s"}]\n' "$TEST_MAIN_PATH"
    ;;
  config-fallback:list:--json)
    printf '[{"Src":"zoxide","Name":"project-zoxide","Path":"%s"}]\n' "$TEST_MAIN_PATH"
    ;;
  zoxide-fallback:list:-t|zoxide-fallback:list:-c)
    printf '[]\n'
    ;;
  zoxide-fallback:list:--json)
    printf '[{"Src":"zoxide","Name":"project-zoxide","Path":"%s"}]\n' "$TEST_MAIN_PATH"
    ;;
  *:connect:*)
    printf 'connected:%s\n' "$2" > "$TEST_CONNECT_RESULT"
    ;;
esac
EOF

cat >"$tmp_dir/bin/tmux" <<'EOF'
#!/usr/bin/env bash
printf 'tmux %s\n' "$*" >> "$TEST_TMUX_LOG"
EOF

chmod +x "$tmp_dir/bin/workmux" "$tmp_dir/bin/sesh" "$tmp_dir/bin/tmux"

export TEST_MAIN_PATH="$tmp_dir/project"
export TEST_SESH_MODE=tmux
export TEST_SESH_LOG="$tmp_dir/sesh.log"
export TEST_TMUX_LOG="$tmp_dir/tmux.log"
export TEST_CONNECT_RESULT="$tmp_dir/connect.result"

PATH="$tmp_dir/bin:$PATH" "$script" "$TEST_MAIN_PATH"

sesh_calls=$(cat "$TEST_SESH_LOG")
assert_contains 'list -t --json' "$sesh_calls"
assert_not_contains 'list --json' "$sesh_calls"
assert_contains 'connected:project' "$(cat "$TEST_CONNECT_RESULT")"

binding=$(grep -F 'bind h run-shell' "$repo_root/tmux/custom-bindings.tmux.conf")
assert_contains 'run-shell -b' "$binding"

printf 'PASS: goto-workmux-main resolves existing tmux sessions without the broad sesh scan\n'

: > "$TEST_SESH_LOG"
TEST_SESH_MODE=config-fallback PATH="$tmp_dir/bin:$PATH" "$script" "$TEST_MAIN_PATH"
sesh_calls=$(cat "$TEST_SESH_LOG")
assert_contains 'list -t --json' "$sesh_calls"
assert_contains 'list -c --json' "$sesh_calls"
assert_not_contains 'list --json' "$sesh_calls"
assert_contains 'connected:project-config' "$(cat "$TEST_CONNECT_RESULT")"
printf 'PASS: configured sessions remain the second lookup source\n'

: > "$TEST_SESH_LOG"
TEST_SESH_MODE=zoxide-fallback PATH="$tmp_dir/bin:$PATH" "$script" "$TEST_MAIN_PATH"
sesh_calls=$(cat "$TEST_SESH_LOG")
assert_contains 'list -t --json' "$sesh_calls"
assert_contains 'list -c --json' "$sesh_calls"
assert_contains 'list --json' "$sesh_calls"
assert_contains 'connected:project-zoxide' "$(cat "$TEST_CONNECT_RESULT")"
printf 'PASS: broad sesh lookup remains available as a fallback\n'

printf 'PASS: tmux binding runs the lookup asynchronously\n'
