#!/bin/sh
set -eu
BIN_ARG="${1:-build/bin}"
EXEEXT="${2:-}"
JOBS="${CMOTIVE_VALIDATE_JOBS:-4}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$BIN_ARG" in
  /*) BIN_DIR="$BIN_ARG" ;;
  *) BIN_DIR="$ROOT/$BIN_ARG" ;;
esac
CMOTIVE="$BIN_DIR/cmotive$EXEEXT"
CMOTIVEPP="$BIN_DIR/cmotivepp$EXEEXT"
OUT="$ROOT/build/all_language_validate"
if [ ! -x "$CMOTIVE" ]; then
  echo "missing executable: $CMOTIVE" >&2
  exit 2
fi
if [ ! -x "$CMOTIVEPP" ]; then
  echo "missing executable: $CMOTIVEPP" >&2
  exit 2
fi
case "$JOBS" in
  ''|*[!0-9]*|0) echo "CMOTIVE_VALIDATE_JOBS must be a positive integer" >&2; exit 2 ;;
esac
rm -rf "$OUT"
mkdir -p "$OUT/pp" "$OUT/obj" "$OUT/log"
(
  cd "$ROOT"
  find . \
    -path './build' -prune -o \
    -path './dist' -prune -o \
    -path './legacy' -prune -o \
    -path './.git' -prune -o \
    -type f \( -iname '*.cmot' -o -iname '*.cmtv' -o -iname '*.hmot' -o -iname '*.hmtv' \) -print | sort
) > "$OUT/language-files.list"
args="$OUT/language-files.args"
: > "$args"
count=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  count=$((count + 1))
  printf '%s\0%s\0%s\0%s\0%s\0%s\0' "$ROOT" "$BIN_DIR" "$EXEEXT" "$OUT" "$count" "$rel" >> "$args"
done < "$OUT/language-files.list"
if [ "$count" -gt 0 ]; then
  xargs -0 -n 6 -P "$JOBS" sh "$ROOT/scripts/validate_one_language_file.sh" < "$args"
fi
actual=$(find "$OUT/obj" -maxdepth 1 -type f | wc -l | tr -d ' ')
if [ "$actual" -ne "$count" ]; then
  echo "CMotive language files: expected $count objects, produced $actual" >&2
  exit 1
fi
echo "CMotive language files: PASS ($count files, $JOBS parallel jobs)"
