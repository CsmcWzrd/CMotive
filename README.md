# CMotive Programming Language Source Archive

CMotive is a native, object-oriented systems programming language. The active
compiler, preprocessor, code generator, command-line driver, and C conversion
tool are now implemented in CMotive itself.

## Active tools

A normal build produces:

- `build/bin/cmotive`
- `build/bin/cmotive++`
- `build/bin/cmotivepp`
- `build/bin/CMotiveSymsToDebugFile`
- `build/bin/c2cmotive`

The active frontend source is:

```text
src/frontend/selfhost/CMotiveFrontend.CMOT
```

The active C-to-CMotive converter source is:

```text
src/tools/CToCMotive.CMOT
```

Neither tool is built from a permanent generated C source file. Generated C is
created under `build/selfhost/` and is ignored by source packaging.

## Bootstrap model

A self-hosted compiler still needs a first executable. CMotive uses an isolated
stage-0 seed at:

```text
bootstrap/c/cmotive_bootstrap.c
```

The build performs these stages:

1. The host C compiler builds the stage-0 seed.
2. Stage 0 compiles `CMotiveFrontend.CMOT` into stage 1.
3. Stage 1 compiles the same CMotive source into stage 2, the installed tool.
4. Stage 2 compiles `CToCMotive.CMOT` into `c2cmotive`.
5. `selfhost-check` asks stage 2 to compile the frontend again and verifies that
   the stage-1, stage-2, and stage-3 generated C files are byte-identical.

The small headers beside the CMotive sources are native ABI boundaries only.
They contain data-layout declarations, varargs helpers, and operating-system
adapters that CMotive cannot yet express portably. Frontend algorithms do not
live in those headers.

No Python is used by the active build, compiler, preprocessor, converter,
tests, example runner, or release packager.

## Build

Linux:

```sh
make -f Makefile.linux clean all
make -f Makefile.linux selfhost-check
make -f Makefile.linux full-test
```

macOS greater than version 15:

```sh
make -f Makefile.mac clean all
make -f Makefile.mac selfhost-check
make -f Makefile.mac full-test
```

Windows with a POSIX shell and MinGW or clang:

```sh
make -f Makefile.windows clean all
make -f Makefile.windows selfhost-check
make -f Makefile.windows full-test
```

Use `CC=clang`, `CC=gcc`, or another C compiler to choose the host compiler.
Use `CMOTIVE_CC` to choose the C compiler invoked for generated C when compiling
CMotive programs.

Useful aggregate targets are:

```sh
make -f Makefile.linux test          # self-host, conformance, converter tests
make -f Makefile.linux full-test     # extended conformance plus converter tests
make -f Makefile.linux examples      # preprocess, compile, and run 158 examples
make -f Makefile.linux language      # preprocess and compile-check every language file
make -f Makefile.linux verify-all    # all of the above
```

Whole-tree language validation defaults to four parallel workers. Override it
with `CMOTIVE_VALIDATE_JOBS=<count>`.

## C to CMotive conversion

`c2cmotive` converts portable C function definitions into CMotive `func`
declarations and bodies. C declarations, ABI types, macros, variadic functions,
and functions containing preprocessor directives are retained in a companion
native support header.

Example:

```sh
build/bin/c2cmotive --verbose \
  -o build/converted/tool.CMOT \
  --support build/converted/tool_native.h \
  --include build/converted/tool_native.h \
  source/tool.c

build/bin/cmotive -I . build/converted/tool.CMOT -o build/converted/tool
```

The converter provides native-to-CMotive symbol bridges, so retained native
functions can call converted CMotive functions. Its test suite converts the
complete stage-0 frontend, compiles the resulting CMotive frontend, and then
uses that converted frontend as both a compiler and a preprocessor.

See `docs/C_TO_CMOTIVE_CONVERTER.md` for supported constructs and limitations.

## Extensions

- Source: `.CMOT`, `.CMTV`
- Header: `.HMOT`, `.HMTV`

## Current frontend capabilities

The self-hosted frontend includes:

- `Plugin`, `Include`, `Replace`, and `Plugswitch` preprocessing
- lexer, parser, semantic checks, and CMotive-to-C lowering
- native compile/link driver through the platform C compiler
- `cmotivepp` preprocessing mode
- CMotive debug-symbol sidecar generation
- package-qualified symbols and separate source inputs
- classes, inheritance, constructors, destructors, `New`, and `Delete`
- overridable methods and pure-virtual declarations
- templates and standard-library container scaffolding
- exception cleanup frames
- object-first `Sys::*` APIs
- dynamic structs, automatic accessors, operation overloads, thread storage,
  global declarations, function pointers, and target/hit dispatch
- brace-delimited and brace-less C-compatible control-flow bodies, required by
  converted C sources

See `docs/FEATURE_STATUS.md` for the broader feature matrix.

## Examples

The merged language examples are under `examples/`. Run them directly with:

```sh
make -f makefile.examples.linux examples
make -f makefile.examples.linux language
```

Equivalent makefiles are provided for macOS and Windows.

The formal variable/member declaration style is `Name : Type = Value;`. Active
language files do not use a `var` prefix.

## Visual Studio 2022

Open `vs2022/CMotive.Packages.sln`. The frontend project is configured as a
self-host build and invokes `vs2022/build-selfhost.cmd` from a Visual Studio
Developer Command Prompt. The C seed is used only for stage 0; the final
`cmotive.exe` and `c2cmotive.exe` are compiled from the CMotive sources.

Windows project files support x64 and ARM64 configurations. The Linux test
report in `VERIFY_SELFHOST_FRONTEND.md` records the verification actually run
in this package; a native VS2022 execution was not available in the Linux test
environment.

## Documentation

- `docs/SELF_HOSTING.md` — bootstrap architecture and fixed-point verification
- `docs/C_TO_CMOTIVE_CONVERTER.md` — converter behavior and usage
- `docs/CMotive-v1-LanguageDefinition.md` — language definition
- `VERIFY_SELFHOST_FRONTEND.md` — exact verification results for this release
