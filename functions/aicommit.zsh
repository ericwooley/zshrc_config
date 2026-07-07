# Create a concise AI-assisted git commit.
# Stages all changes, asks fastAI for an imperative subject under 50 chars,
# strips risky shell quoting, and commits with that message.
aicommit() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "aicommit: not inside a git repository" >&2
    return 1
  fi

  git add --all || return

  local diff
  diff="$(git diff --cached --no-ext-diff --no-color)"
  if [[ -z "$diff" ]]; then
    echo "aicommit: nothing to commit" >&2
    return 1
  fi

  local prompt
  prompt=$'Write a concise git commit subject for this staged diff.\n\nRules:\n- Output only the commit message.\n- Use imperative mood.\n- Keep it under 50 characters.\n- No quotes, markdown, bullets, explanations, or trailing period.\n\nDiff:\n'"$diff"

  local message
  message="$(
    fastAI \
      --provider "${FASTAI_DEFAULT_PROVIDER:-openrouter}" \
      --model "${FASTAI_DEFAULT_MODEL:-deepseek/deepseek-v4-flash}" \
      --permissions none \
      --no-session \
      "$prompt"
  )" || return

  message="${message%%$'\n'*}"
  message="${message//$'\r'/}"
  message="${message//\"/}"
  message="${message//\`/}"
  message="${message#"${message%%[![:space:]]*}"}"
  message="${message%"${message##*[![:space:]]}"}"

  if [[ -z "$message" ]]; then
    echo "aicommit: fastAI returned an empty commit message" >&2
    return 1
  fi

  if (( ${#message} > 50 )); then
    message="${message[1,50]}"
  fi

  echo "aicommit: $message"
  git commit -am "$message"
}
alias aiCommit=aicommit
