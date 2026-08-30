# CMotive 1,200-case QA verification

Verification date: 2026-08-30 UTC  
Release version: `0.3.0-selfhost`

## Suite integrity

The checked-in `manifest.tsv` contains exactly **1,200 unique test IDs**. The
runner rejects missing, duplicate, and unknown result IDs. The final Linux run
reported:

```text
Manifest tests:       1200
Reported results:     1200
Passed:               1200
Failed:               0
Duplicate result IDs: 0
Missing result IDs:   0
Unknown result IDs:   0
```

Category results:

| Category | Tests | Passed | Failed |
|---|---:|---:|---:|
| Runtime language semantics | 640 | 640 | 0 |
| Preprocessor | 192 | 192 | 0 |
| Advanced language/standard library | 96 | 96 | 0 |
| Compiler and tool CLI | 128 | 128 | 0 |
| C-to-CMotive converter | 96 | 96 | 0 |
| Expected failures/diagnostics | 48 | 48 | 0 |
| **Total** | **1,200** | **1,200** | **0** |

The final catalogued run completed in 27 seconds on the verification host.

## Commands and results

### Self-host fixed point

```sh
make -f Makefile.linux all selfhost-check
```

```text
CMotive self-host fixed-point and behavior: PASS
```

Stage-1, stage-2, and stage-3 generated frontend C outputs are byte-identical:

```text
234844823a813797df9b3b234bb3aa3bc0991ef1e2a6091904fd8da1308565ff
```

### New QA catalog

```sh
make -f Makefile.linux qa
```

```text
CMotive QA summary: 1200 passed, 0 failed, 1200 manifest tests
```

### Existing compiler conformance

```sh
sh scripts/run_tests.sh build/bin "" --full
```

```text
CMotive tests: PASS
```

### Existing converter migration suite

```sh
sh scripts/run_converter_tests.sh build/bin ""
```

```text
c2cmotive tests: PASS (3 fixtures, default paths, preserve mode, complete frontend migration)
```

The complete frontend conversion continues to produce two non-fatal
`const`-qualifier warnings in its generated native bridge. The resulting
frontend compiles and passes its compiler and preprocessor behavior checks.

### Merged language examples

```sh
sh scripts/run_examples.sh build/bin ""
```

```text
CMotive examples: PASS (158 examples)
```

Every example was preprocessed, compiled, linked, and executed.

### Whole-source language sweep

```sh
CMOTIVE_VALIDATE_JOBS=8 sh scripts/validate_language_files.sh build/bin ""
```

```text
CMotive language files: PASS (311 files, 8 parallel jobs)
```

Every positive `.CMOT`, `.CMTV`, `.HMOT`, and `.HMTV` file outside generated,
legacy, and release-output directories was preprocessed and object-compiled.
Expected-failure fixtures use non-language fixture suffixes so they cannot
pollute this positive sweep.

## Frontend defect found by the expanded suite

The repository-wide example run exposed an object-layout defect for classes
whose storage is supplied by the builtin runtime, including `Thread` and
`Threading`. Header-defined constructors attempted to initialize the internal
`__cmotive_type` field even though builtin runtime structs intentionally do not
own that field.

`emit_class_initialization` now emits the runtime type tag only for frontend-
generated class layouts. A permanent regression is included in
`quality-assurance/cases/features/23_thread.CMOT`, which includes the actual
`Sys/Thread.HMOT` header and constructs both builtin thread object forms.

## Verification environment

```text
Linux 6.18.35 x86_64
GCC 14.2.0
GNU Make 4.4.1
```

Linux compilation and execution were performed directly. macOS and native
Visual Studio 2022 execution were not available on this host; their Makefiles,
wrapper, project XML, source references, and QA targets received static checks
inside the 128 tool tests.
