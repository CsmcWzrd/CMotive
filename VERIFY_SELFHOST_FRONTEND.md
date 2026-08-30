# CMotive self-hosted frontend verification

Verification date: 2026-08-30 UTC  
Release version: `0.3.0-selfhost`

## Verified architecture

- Active frontend: `src/frontend/selfhost/CMotiveFrontend.CMOT`
- Native frontend ABI boundary: `src/frontend/selfhost/cmotive_frontend_support.h`
- Isolated stage-0 seed: `bootstrap/c/cmotive_bootstrap.c`
- Active converter: `src/tools/CToCMotive.CMOT`
- Converter ABI boundary: `src/tools/c2cmotive_support.h`
- Common bootstrap rules: `mk/selfhost.mk`

The deleted `src/native/cmotivetool.c` path is no longer used by any active
build. The C seed is used only to create stage 1. The final compiler,
preprocessor, symbol-tool dispatcher, and `c2cmotive` executable are compiled
from CMotive sources.

## Linux verification environment

```text
Linux 6.18.35 x86_64
GCC 14.2.0
GNU Make 4.4.1
```

## Clean bootstrap and fixed point

Command:

```sh
make -f Makefile.linux clean all selfhost-check
```

Result:

```text
CMotive self-host fixed-point and behavior: PASS
```

Tool versions:

```text
stage 0: CMotive compiler 0.3.0-selfhost-bootstrap
stage 1: CMotive compiler 0.3.0-selfhost
final:   CMotive compiler 0.3.0-selfhost
c2cmotive 0.3.0-selfhost
```

The stage-1, stage-2, and stage-3 generated frontend C files were compared
byte-for-byte. All three have this SHA-256:

```text
bd9c5c7ce209d0119472506941b5ab7ff7fff08f1b0c1cdafc5638ae7df9addf
```

The behavioral self-host check also verified:

- identical stage-1 and final generated C for a conformance input;
- strict-C11 compilation and execution of emitted C;
- identical stage-1 and final preprocessor output;
- identical execution results for programs built by stage 1 and the final
  compiler.

## Compiler, preprocessor, and converter tests

Command:

```sh
make -f Makefile.linux full-test
```

Results:

```text
CMotive self-host fixed-point and behavior: PASS
CMotive tests: PASS
c2cmotive tests: PASS (3 fixtures, default paths, preserve mode, complete frontend migration)
```

The converter suite verifies executable conversions, default and explicit
output paths, CMotive keyword rewriting, C-keyword-preserving mode, strings,
comments, arrays, pointers, variadic/native retention, preprocessing, and
compilation.

For the migration-scale test, `c2cmotive` converted the complete stage-0
frontend:

```text
converted 123 functions
retained 6 native ABI functions
```

The resulting CMotive source and native support header were compiled into a
working frontend. That converted frontend then compiled a conformance program
and processed a preprocessor conformance source successfully.

The complete stage-0 conversion currently produces two non-fatal C qualifier
warnings in the generated native bridge because CMotive pointer signatures do
not yet preserve C `const` qualifiers. This review case is documented in
`docs/C_TO_CMOTIVE_CONVERTER.md`; it does not change the tested runtime output.


## Expanded quality-assurance catalog

Command:

```sh
make -f Makefile.linux qa
```

Result:

```text
CMotive QA summary: 1200 passed, 0 failed, 1200 manifest tests
```

The checked-in suite under `quality-assurance/` contains 1,200 unique, stable
case IDs: 640 runtime-language assertions, 192 preprocessor assertions, 96
advanced language/standard-library assertions, 128 compiler/tool assertions,
96 C-to-CMotive converter assertions, and 48 expected-failure diagnostics. The
runner verified zero duplicate, missing, or unknown result IDs.

The expanded regression found and fixed a builtin-class layout issue: classes
loaded from headers such as `Thread` and `Threading` used runtime-supplied
structs without `__cmotive_type`, while their generated constructors attempted
to initialize that field. Type-tag initialization is now limited to
frontend-generated class layouts, and the actual `Sys/Thread.HMOT` path is
covered by a permanent QA fixture.

See `quality-assurance/VERIFICATION.md` for the category-level results and exact
commands.

## Merged examples

Command:

```sh
make -f Makefile.linux examples
```

Result:

```text
CMotive examples: PASS (158 examples)
```

Each example was preprocessed, compiled with the final frontend, and executed.

## Whole-tree language validation

Command:

```sh
make -f Makefile.linux language
```

Result:

```text
CMotive language files: PASS (312 files, 4 parallel jobs)
```

Every `.CMOT`, `.CMTV`, `.HMOT`, and `.HMTV` file outside generated, legacy,
and release-output directories was preprocessed and compiled to an object.
The declaration scan found zero `var Name`-style declarations.

## Relocation and emitted-C verification

The final compiler and preprocessor were copied to the nested directory
`build/bin/Release-x64/` and invoked from an unrelated working directory. The
following all passed:

- root discovery from the nested executable location;
- CMotive-to-C emission;
- preprocessor output;
- direct strict-C11 compilation and execution of the emitted C;
- normal compiler-driver compilation and execution.

Result:

```text
CMotive relocation and strict-C11 emitted-C test: PASS
```

## Build-file validation

- All 12 shell scripts passed `sh -n` parsing.
- All four VS2022 `.vcxproj`/`.filters` XML files parsed successfully.
- The VS2022 solution now references `CMotive.SelfHostedFrontend.vcxproj`.
- Windows Makefile linkage includes Winsock for the generated runtime.
- Emitted C defines the required non-Windows feature macros before native and
  system includes.

Linux builds and runtime tests were executed in this environment. macOS and
native Visual Studio 2022 execution were not available here, so those platform
files received static validation rather than a claimed native runtime pass.

## Portable integer stream-I/O and license follow-up

The compiler-generated runtime now formats `int64_t` through the C standard
`SCNd64` and `PRId64` macros. This removes the `%lld`/`int64_t *` mismatch on
LP64 targets. The self-hosted source, stage-0 bootstrap seed, standard-library
object API, and legacy bootstrap copy were updated consistently. Strict emitted
C is compiled with `-Werror=format`, and a signed 64-bit input/output round-trip
is part of the permanent tool QA.

The root `LICENSE` is now the complete MIT License, and release packaging is
covered by a content-level license regression check. Detailed evidence is in
`VERIFY_RUNTIME_IO_MIT_LICENSE.md`.
