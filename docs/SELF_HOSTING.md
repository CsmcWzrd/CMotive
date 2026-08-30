# CMotive self-hosting architecture

## Source ownership

The compiler frontend is maintained as CMotive source in
`src/frontend/selfhost/CMotiveFrontend.CMOT`. It contains preprocessing,
lexing, parsing, semantic checks, lowering, debug metadata, command-line option
handling, and compiler/preprocessor/symbol-tool dispatch.

`src/frontend/selfhost/cmotive_frontend_support.h` is a deliberately narrow
native boundary. It contains:

- frontend structure and enum layouts needed at the C ABI boundary;
- the varargs implementation of the string-builder formatting helper;
- platform adapters for directory creation, process execution, temporary
  directories, process IDs, current directories, OS selection, and CPU
  selection.

No parser, preprocessor, lowering, or driver algorithm is implemented in that
header.

## Bootstrap stages

The source tree retains `bootstrap/c/cmotive_bootstrap.c` as stage 0. It is not
the active frontend and is not installed. Its purpose is to compile the first
copy of the CMotive frontend on a system that has no CMotive compiler yet.

The common build rules in `mk/selfhost.mk` create:

```text
build/bootstrap/cmotive-stage0
build/selfhost/CMotiveFrontend.stage1.c
build/stage1/cmotive
build/selfhost/CMotiveFrontend.stage2.c
build/bin/cmotive
build/selfhost/CMotiveFrontend.stage3.c  # verification only
```

Stage 0 emits stage-1 C. Stage 1 emits stage-2 C. The final stage-2 compiler
emits stage-3 C during `selfhost-check`.

## Fixed-point requirement

A successful self-host check requires:

```text
CMotiveFrontend.stage1.c == CMotiveFrontend.stage2.c
CMotiveFrontend.stage2.c == CMotiveFrontend.stage3.c
```

The comparison is byte-for-byte, not merely a successful compile. The
behavioral check additionally compares:

- generated C for a conformance program;
- strict-C11 compilation of the emitted C artifact;
- preprocessor output from stage 1 and stage 2;
- execution results from programs compiled by stage 1 and stage 2.

Run it with:

```sh
make -f Makefile.linux selfhost-check
```

## NativeInclude

Self-hosting added the top-level declaration:

```text
NativeInclude "path/to/header.h";
```

The frontend emits these headers before its generated standard-library/runtime
preamble. This allows a CMotive translation unit to declare a controlled native
ABI boundary without moving algorithms back into C.

## Reproducibility and generated files

Generated C and binaries live under `build/`, which is excluded from release
source archives. A clean build recreates every generated file from the C seed
and CMotive sources. The release therefore does not depend on an unchecked-in
generated frontend.

## Updating the frontend

When editing `CMotiveFrontend.CMOT`, update the stage-0 seed only when the edit
changes syntax or semantics needed to compile the active frontend. Ordinary
frontend implementation changes belong only in the CMotive source.

Before release, run:

```sh
make -f Makefile.linux clean all
make -f Makefile.linux selfhost-check
make -f Makefile.linux full-test
make -f makefile.examples.linux examples
make -f makefile.examples.linux language
```
