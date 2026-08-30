#!/bin/sh
set -eu
BIN_ARG="${1:-build/bin}"
EXEEXT="${2:-}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$BIN_ARG" in /*) BIN_DIR="$BIN_ARG" ;; *) BIN_DIR="$ROOT/$BIN_ARG" ;; esac
CMOTIVE="$BIN_DIR/cmotive$EXEEXT"
CMOTIVEPP="$BIN_DIR/cmotivepp$EXEEXT"
C2CMOTIVE="$BIN_DIR/c2cmotive$EXEEXT"
OUT="$ROOT/build/converter_tests"
FIXTURES="$ROOT/tests/converter"
rm -rf "$OUT"
mkdir -p "$OUT"

"$C2CMOTIVE" --version | grep -q 'c2cmotive 0.3.0-selfhost'
"$C2CMOTIVE" --help | grep -q -- '--support FILE'

run_fixture() {
    name="$1"
    mkdir -p "$OUT/$name"
    "$C2CMOTIVE" --verbose \
        -o "$OUT/$name/$name.CMOT" \
        --support "$OUT/$name/${name}_native.h" \
        --include "build/converter_tests/$name/${name}_native.h" \
        "$FIXTURES/$name.c" > "$OUT/$name/converter.log"
    grep -q 'converted [1-9][0-9]* function' "$OUT/$name/converter.log"
    grep -q '^NativeInclude ' "$OUT/$name/$name.CMOT"
    "$CMOTIVEPP" -I "$ROOT" "$OUT/$name/$name.CMOT" -o "$OUT/$name/$name.pp.CMOT"
    CMOTIVE_CC="${CMOTIVE_CC:-cc}" "$CMOTIVE" -I "$ROOT" "$OUT/$name/$name.CMOT" -o "$OUT/$name/$name$EXEEXT"
    "$OUT/$name/$name$EXEEXT" > "$OUT/$name/actual.out"
    cmp "$FIXTURES/$name.expected" "$OUT/$name/actual.out"
}

run_fixture basic
run_fixture control_flow
run_fixture arrays_strings

grep -q 'If (' "$OUT/control_flow/control_flow.CMOT"
grep -q 'Else If' "$OUT/control_flow/control_flow.CMOT"
grep -q 'For (' "$OUT/control_flow/control_flow.CMOT"
grep -q 'While (' "$OUT/control_flow/control_flow.CMOT"
grep -q 'Do' "$OUT/control_flow/control_flow.CMOT"
grep -q 'Switch (' "$OUT/control_flow/control_flow.CMOT"
grep -q 'const if return must stay inside this string' "$OUT/arrays_strings/arrays_strings.CMOT"
grep -q 'const, if and return must also stay inside this comment' "$OUT/arrays_strings/arrays_strings.CMOT"

mkdir -p "$OUT/preserve"
"$C2CMOTIVE" --preserve-keywords \
    -o "$OUT/preserve/control_flow.CMOT" \
    --support "$OUT/preserve/control_flow_native.h" \
    --include "build/converter_tests/preserve/control_flow_native.h" \
    "$FIXTURES/control_flow.c"
grep -q 'for (' "$OUT/preserve/control_flow.CMOT"
grep -q 'return value' "$OUT/preserve/control_flow.CMOT"
CMOTIVE_CC="${CMOTIVE_CC:-cc}" "$CMOTIVE" -I "$ROOT" "$OUT/preserve/control_flow.CMOT" -o "$OUT/preserve/control_flow$EXEEXT"
"$OUT/preserve/control_flow$EXEEXT" > "$OUT/preserve/actual.out"
cmp "$FIXTURES/control_flow.expected" "$OUT/preserve/actual.out"

# Default-path test: the generated NativeInclude uses the support path, so a
# converted source in a subdirectory compiles without an extra include flag.
mkdir -p "$OUT/default"
cp "$FIXTURES/basic.c" "$OUT/default/default.c"
"$C2CMOTIVE" "$OUT/default/default.c"
grep -q "NativeInclude \"$OUT/default/default_native.h\";" "$OUT/default/default.CMOT"
CMOTIVE_CC="${CMOTIVE_CC:-cc}" "$CMOTIVE" "$OUT/default/default.CMOT" -o "$OUT/default/default$EXEEXT"
"$OUT/default/default$EXEEXT" > "$OUT/default/actual.out"
cmp "$FIXTURES/basic.expected" "$OUT/default/actual.out"

# Migration-scale test: convert the complete C stage-0 seed, compile the
# resulting CMotive frontend, then exercise both compiler and preprocessor.
mkdir -p "$OUT/frontend"
"$C2CMOTIVE" --verbose \
    -o "$OUT/frontend/CMotiveFrontendFromC.CMOT" \
    --support "$OUT/frontend/cmotive_frontend_from_c_native.h" \
    --include "build/converter_tests/frontend/cmotive_frontend_from_c_native.h" \
    "$ROOT/bootstrap/c/cmotive_bootstrap.c" > "$OUT/frontend/converter.log"
grep -Eq 'converted (1[0-9][0-9]|[2-9][0-9]) function' "$OUT/frontend/converter.log"
CMOTIVE_CC="${CMOTIVE_CC:-cc}" "$CMOTIVE" -I "$ROOT" "$OUT/frontend/CMotiveFrontendFromC.CMOT" -o "$OUT/frontend/cmotive-from-c$EXEEXT"
"$OUT/frontend/cmotive-from-c$EXEEXT" --version | grep -q '0.3.0-selfhost-bootstrap'
cp "$OUT/frontend/cmotive-from-c$EXEEXT" "$OUT/frontend/cmotivepp-from-c$EXEEXT"
chmod +x "$OUT/frontend/cmotivepp-from-c$EXEEXT" 2>/dev/null || true
CMOTIVE_CC="${CMOTIVE_CC:-cc}" "$OUT/frontend/cmotive-from-c$EXEEXT" "$ROOT/tests/conformance/basic.CMOT" -o "$OUT/frontend/basic$EXEEXT"
"$OUT/frontend/basic$EXEEXT"
"$OUT/frontend/cmotivepp-from-c$EXEEXT" -I "$ROOT/lib" "$ROOT/tests/conformance/cmotive_preprocessor.CMOT" -o "$OUT/frontend/preprocessed.CMOT"
grep -q 'main' "$OUT/frontend/preprocessed.CMOT"

echo "c2cmotive tests: PASS (3 fixtures, default paths, preserve mode, complete frontend migration)"
