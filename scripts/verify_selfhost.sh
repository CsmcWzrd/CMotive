#!/bin/sh
set -eu
STAGE1_ARG="${1:-build/stage1}"
FINAL_ARG="${2:-build/bin}"
EXEEXT="${3:-}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$STAGE1_ARG" in /*) STAGE1_DIR="$STAGE1_ARG" ;; *) STAGE1_DIR="$ROOT/$STAGE1_ARG" ;; esac
case "$FINAL_ARG" in /*) FINAL_DIR="$FINAL_ARG" ;; *) FINAL_DIR="$ROOT/$FINAL_ARG" ;; esac
STAGE1="$STAGE1_DIR/cmotive$EXEEXT"
STAGE1PP="$STAGE1_DIR/cmotivepp$EXEEXT"
FINAL="$FINAL_DIR/cmotive$EXEEXT"
FINALPP="$FINAL_DIR/cmotivepp$EXEEXT"
OUT="$ROOT/build/selfhost/behavior"
rm -rf "$OUT"
mkdir -p "$OUT"

"$STAGE1" --version > "$OUT/stage1.version"
"$FINAL" --version > "$OUT/stage2.version"
grep -q '0.3.0-selfhost' "$OUT/stage1.version"
grep -q '0.3.0-selfhost' "$OUT/stage2.version"

"$STAGE1" --emit-c "$ROOT/tests/conformance/basic.CMOT" -o "$OUT/stage1.basic.c"
"$FINAL" --emit-c "$ROOT/tests/conformance/basic.CMOT" -o "$OUT/stage2.basic.c"
cmp "$OUT/stage1.basic.c" "$OUT/stage2.basic.c"

# The emitted C is a supported artifact and must compile in strict C11 mode,
# not only in a compiler's default GNU dialect.
CMOTIVE_CC_BIN="${CMOTIVE_CC:-cc}"
"$CMOTIVE_CC_BIN" -std=c11 -I"$ROOT/lib/Sys" "$OUT/stage2.basic.c" -pthread -lm -o "$OUT/stage2-basic-strict-c11$EXEEXT"
"$OUT/stage2-basic-strict-c11$EXEEXT" > "$OUT/stage2.strict-c11.run"

"$STAGE1PP" -I "$ROOT/lib" "$ROOT/tests/conformance/cmotive_preprocessor.CMOT" -o "$OUT/stage1.preprocessed.CMOT"
"$FINALPP" -I "$ROOT/lib" "$ROOT/tests/conformance/cmotive_preprocessor.CMOT" -o "$OUT/stage2.preprocessed.CMOT"
cmp "$OUT/stage1.preprocessed.CMOT" "$OUT/stage2.preprocessed.CMOT"

CMOTIVE_CC="${CMOTIVE_CC:-cc}" "$STAGE1" "$ROOT/tests/conformance/basic.CMOT" -o "$OUT/stage1-basic$EXEEXT"
CMOTIVE_CC="${CMOTIVE_CC:-cc}" "$FINAL" "$ROOT/tests/conformance/basic.CMOT" -o "$OUT/stage2-basic$EXEEXT"
"$OUT/stage1-basic$EXEEXT" > "$OUT/stage1.run"
"$OUT/stage2-basic$EXEEXT" > "$OUT/stage2.run"
cmp "$OUT/stage1.run" "$OUT/stage2.run"

echo "CMotive self-host fixed-point and behavior: PASS"
