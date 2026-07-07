# Create a directory and immediately change into it.
# Usage: mkcd <directory>
mkcd() {
  if (( $# != 1 )); then
    echo "usage: mkcd <directory>" >&2
    return 2
  fi

  mkdir -p -- "$1" && cd -- "$1"
}
