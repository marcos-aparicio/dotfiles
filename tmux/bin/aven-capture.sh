#!/bin/sh
# aven-capture — global natural-language capture into aven.
#
# Unlike `aven add --natural`, this is cwd-independent and can fan out to
# SEVERAL projects from one sentence:
#
#   "solve this bug on acme-ca and all the other eu repos"
#
# aven's built-in intake returns exactly one task for one project, so the
# multi-repo case needs this. Related tasks are tied together with a shared
# `batch` metadata field rather than an epic, because aven epics are strictly
# single-project (`error epic-cross-project`).
#
# Nothing is created until you confirm.
#
# Optional project aliases, so "the eu repos" resolves to real project keys:
#   ~/.config/aven/capture-groups.json
#   { "eu": ["acme-de","acme-fr"], "na": ["acme-ca","acme-us"] }

set -eu

GROUPS_FILE="${AVEN_CAPTURE_GROUPS:-$HOME/.config/aven/capture-groups.json}"
AVEN="${AVEN_BIN:-aven}"

die() { printf '%s\n' "$*" >&2; exit 1; }

command -v "$AVEN" >/dev/null 2>&1 || die "aven not found on PATH"
command -v pi     >/dev/null 2>&1 || die "pi not found on PATH"
command -v jq     >/dev/null 2>&1 || die "jq not found on PATH"

# ---------------------------------------------------------------- input ----
raw="$*"
if [ -z "$raw" ]; then
    printf 'Capture: '
    IFS= read -r raw || exit 0
fi
[ -n "$raw" ] || exit 0

# ------------------------------------------------------------- context ----
projects=$("$AVEN" project list --json 2>/dev/null \
    | jq -r '.[] | "- \(.key) (\(.name))"' 2>/dev/null || true)
[ -n "$projects" ] || die "No aven projects yet. Create one first:
  aven project create <name> --path ~/Projects/<repo>"

labels=$("$AVEN" label list --json 2>/dev/null \
    | jq -r '.[].name' 2>/dev/null || true)
[ -n "$labels" ] || labels="(none)"

groups="(none configured)"
if [ -f "$GROUPS_FILE" ]; then
    groups=$(jq -r 'to_entries[] | "- \(.key): \(.value | join(", "))"' \
        "$GROUPS_FILE" 2>/dev/null || echo "(none configured)")
fi

# -------------------------------------------------------------- intake ----
prompt=$(cat <<EOF
You turn one raw capture into Aven task payloads. Return ONLY JSON, no prose,
no markdown fences.

Shape:
{"batch":"short-kebab-slug or null","tasks":[{"title":"...","project":"exact project key","priority":"none|low|medium|high|urgent","description":"optional","labels":["existing label"]}]}

Rules:
- Emit ONE task per project the text targets. A single-project capture yields
  exactly one task.
- "project" MUST be one of the exact project keys listed below. Never invent one.
- If the text names a project group, expand it to that group's project keys.
- If no project is clearly identifiable, return {"batch":null,"tasks":[]}.
- Titles are concise and imperative, starting with a capitalized verb. Keep
  meaningful casing for names, acronyms, files, flags, and code identifiers.
- When there is more than one task, set "batch" to a short slug naming the
  shared piece of work. Otherwise set it to null.
- Use only labels from the existing list. Omit the field when none apply.
- Put durable context in "description" only when it adds something beyond the
  title. Omit otherwise.

Available projects:
$projects

Project groups:
$groups

Existing labels:
$labels

Raw capture text:
$raw
EOF
)

printf 'Thinking...\n' >&2
out=$(printf '%s' "$prompt" | pi --print --no-session --no-tools --no-extensions \
    --no-skills --no-prompt-templates --no-context-files --no-approve 2>/dev/null) \
    || die "intake failed (pi returned non-zero)"

# tolerate ```json fences or surrounding prose
json=$(printf '%s' "$out" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//' \
    | awk '/^[[:space:]]*\{/,0' )
printf '%s' "$json" | jq -e . >/dev/null 2>&1 \
    || die "intake did not return valid JSON. Raw output:
$out"

count=$(printf '%s' "$json" | jq '.tasks | length')
[ "$count" -gt 0 ] || die "Could not identify a project from that text.
Name a project or group explicitly, e.g. \"... on acme-ca and the eu repos\"."

# ------------------------------------------------------------ validate ----
valid=$("$AVEN" project list --json | jq -r '.[].key')
bad=""
for p in $(printf '%s' "$json" | jq -r '.tasks[].project'); do
    printf '%s\n' "$valid" | grep -qxF "$p" || bad="$bad $p"
done
[ -z "$bad" ] || die "intake returned unknown project(s):$bad"

batch=$(printf '%s' "$json" | jq -r '.batch // empty')
[ "$count" -gt 1 ] || batch=""

# ------------------------------------------------------------- preview ----
printf '\n'
printf '%s' "$json" | jq -r '.tasks[] | "  [\(.project)] \(.title)   (\(.priority // "none"))"'
[ -n "$batch" ] && printf '\n  batch=%s\n' "$batch"
printf '\nCreate %s task(s)? [y/N] ' "$count"
IFS= read -r reply || exit 0
case "$reply" in
    y|Y|yes|YES) ;;
    *) printf 'Aborted.\n'; exit 0 ;;
esac

# -------------------------------------------------------------- create ----
printf '\n'
i=0
while [ "$i" -lt "$count" ]; do
    t=$(printf '%s' "$json" | jq -c ".tasks[$i]")
    title=$(printf   '%s' "$t" | jq -r '.title')
    project=$(printf '%s' "$t" | jq -r '.project')
    priority=$(printf '%s' "$t" | jq -r '.priority // "none"')
    desc=$(printf    '%s' "$t" | jq -r '.description // empty')

    set -- add "$title" --project "$project" --priority "$priority"
    [ -n "$batch" ] && set -- "$@" --metadata "batch=$batch"
    for l in $(printf '%s' "$t" | jq -r '.labels[]? // empty'); do
        set -- "$@" --label "$l"
    done

    if [ -n "$desc" ]; then
        printf '%s' "$desc" | "$AVEN" "$@" --description-stdin
    else
        "$AVEN" "$@"
    fi
    i=$((i + 1))
done

[ -n "$batch" ] && printf '\nReview together:  aven list --metadata batch=%s\n' "$batch"
printf '\nPress enter to close. '
IFS= read -r _ || true
