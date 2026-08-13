#!/usr/bin/env bash
# SessionStart hook: report whether this repo is in sync with GitHub.
# Always exits 0 — a network failure or a non-git directory must never block a session.

set -uo pipefail

emit() {
  # $1 = systemMessage (shown to the user), $2 = additionalContext (injected for Claude)
  printf '{"systemMessage":%s,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
    "$(json_str "$1")" "$(json_str "$2")"
  exit 0
}

json_str() {
  # Minimal JSON string escaping — backslash, quote, newline, tab, CR.
  local s=${1//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/}
  printf '"%s"' "$s"
}

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0

# No upstream configured — nothing to compare against.
if ! upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
  emit "git: '$branch' has no upstream — nothing to sync against." \
       "Repo check: branch '$branch' has no upstream branch configured, so sync state is unknown."
fi

# Fetch, but never hang a session on a dead network.
# Retry with schannel: Git Bash's bundled CA store fails to verify github.com on some
# Windows installs, while the native Windows TLS stack succeeds.
fetch_note=""
if ! timeout 20 git fetch --quiet --all --prune 2>/dev/null; then
  if ! timeout 20 git -c http.sslBackend=schannel fetch --quiet --all --prune 2>/dev/null; then
    fetch_note=" (fetch failed — offline or auth issue; counts may be stale)"
  fi
fi

counts=$(git rev-list --left-right --count "@{u}...HEAD" 2>/dev/null) || exit 0
behind=$(printf '%s' "$counts" | awk '{print $1}')
ahead=$(printf '%s' "$counts" | awk '{print $2}')
behind=${behind:-0}
ahead=${ahead:-0}

dirty=0
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then dirty=1; fi
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

state=""
action=""
if [ "$behind" -gt 0 ] && [ "$ahead" -gt 0 ]; then
  state="DIVERGED: $ahead ahead, $behind behind $upstream"
  action="Local and remote have both moved. Reconcile with a rebase or merge before pushing; do not force-push."
elif [ "$behind" -gt 0 ]; then
  state="BEHIND by $behind commit(s) vs $upstream"
  action="A pull is needed. Run 'git pull --rebase' before starting work."
elif [ "$ahead" -gt 0 ]; then
  state="AHEAD by $ahead commit(s) vs $upstream"
  action="Local commits are not pushed yet."
else
  state="up to date with $upstream"
  action="No pull needed."
fi

extra=""
[ "$dirty" -eq 1 ] && extra="${extra}, uncommitted changes"
[ "$untracked" -gt 0 ] && extra="${extra}, $untracked untracked file(s)"

emit "git [$branch] $state$extra$fetch_note" \
     "Repo sync check at session start — branch '$branch': $state$extra$fetch_note. $action"
