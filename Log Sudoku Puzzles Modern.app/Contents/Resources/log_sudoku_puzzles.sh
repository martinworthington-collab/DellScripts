#!/usr/bin/env bash
set -euo pipefail

# Prints compact puzzle strings from generator .Large files.
# Usage:
#   scripts/log_sudoku_puzzles.sh /path/to/output-dir
#   scripts/log_sudoku_puzzles.sh file1.Large file2.Large

print_usage() {
  echo "Usage: $0 <folder-with-.Large-files | .Large files...>" >&2
  exit 1
}

[[ $# -gt 0 ]] || print_usage

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
declare -a files=()

collect_from_dir() {
  local dir="$1"
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$dir" -maxdepth 1 -type f -name '*.Large' -print0 | sort -z)
}

for arg in "$@"; do
  if [[ -d "$arg" ]]; then
    collect_from_dir "$arg"
  else
    files+=("$arg")
  fi
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .Large files found." >&2
  exit 1
fi

"$script_dir/log_sudoku_puzzles.pl" "${files[@]}"
