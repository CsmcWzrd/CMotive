#!/bin/sh
set -eu
ROOT="$1"
BIN_DIR="$2"
EXEEXT="$3"
OUT="$4"
index="$5"
rel="$6"
CMOTIVE="$BIN_DIR/cmotive$EXEEXT"
CMOTIVEPP="$BIN_DIR/cmotivepp$EXEEXT"
f="$ROOT/${rel#./}"
safe=$(printf '%04d_%s' "$index" "${rel#./}" | sed 's#[^A-Za-z0-9_.-]#_#g')
"$CMOTIVEPP" -I "$ROOT/examples/headers" -I "$ROOT/examples/packages" -I "$ROOT/lib" "$f" -o "$OUT/pp/$safe.pp.CMOT" >"$OUT/log/$safe.pp.out" 2>"$OUT/log/$safe.pp.err"
"$CMOTIVE" -c -I "$ROOT/examples/headers" -I "$ROOT/examples/packages" -I "$ROOT/lib" "$f" -o "$OUT/obj/$safe.o" >"$OUT/log/$safe.cc.out" 2>"$OUT/log/$safe.cc.err"
