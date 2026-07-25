# Make Homebrew available before loading tools installed through it.

_zshrc_homebrew_executable=""

if command -v brew >/dev/null 2>&1; then
  _zshrc_homebrew_executable="$(command -v brew)"
else
  case "$(uname -s)" in
    Darwin)
      _zshrc_homebrew_candidates=(
        /opt/homebrew/bin/brew
        /usr/local/bin/brew
      )
      ;;
    Linux)
      _zshrc_homebrew_candidates=(
        /home/linuxbrew/.linuxbrew/bin/brew
      )
      ;;
    *)
      _zshrc_homebrew_candidates=()
      ;;
  esac

  for _zshrc_homebrew_candidate in "${_zshrc_homebrew_candidates[@]}"; do
    if [[ -x "$_zshrc_homebrew_candidate" ]]; then
      _zshrc_homebrew_executable="$_zshrc_homebrew_candidate"
      break
    fi
  done
fi

if [[ -n "$_zshrc_homebrew_executable" ]]; then
  _zshrc_homebrew_environment="$("$_zshrc_homebrew_executable" shellenv 2>/dev/null)"
  if [[ -n "$_zshrc_homebrew_environment" ]]; then
    eval "$_zshrc_homebrew_environment"
  fi
fi

unset _zshrc_homebrew_candidate
unset _zshrc_homebrew_candidates
unset _zshrc_homebrew_environment
unset _zshrc_homebrew_executable
