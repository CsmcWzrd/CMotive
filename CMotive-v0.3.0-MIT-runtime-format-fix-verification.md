# CMotive portable 64-bit stream I/O and MIT-license verification

Verification date: 2026-08-30 UTC  
Release version: `0.3.0-selfhost`

## Corrected compiler-generated C

The generated runtime previously used this fixed conversion:

```c
scanf("%lld", out);
```

That is not portable for `int64_t *`. On LP64 platforms such as 64-bit Linux,
`int64_t` is normally `long`, while `%lld` requires `long long *`. GCC therefore
reported a format-type mismatch for the compiler-generated runtime.

The runtime and both bootstrap implementations now include `<inttypes.h>` and
use the standard portable integer format macros:

```c
scanf("%" SCNd64, out);
printf("%" PRId64, value);
```

The input stream's default format is now selected by the typed operation rather
than being initialized to the unrelated string format `%s`. Null output
pointers are rejected with `errno = EINVAL` and `EOF`.

The self-hosted frontend and isolated stage-0 bootstrap were updated together,
so `OStream.WriteInt`, `OStream.Println`, `OStream.Flush`, `IStream.Expect`,
`IStream.ReadInt`, and `IStream.ReadString` lower consistently in every
bootstrap stage. The legacy Python bootstrap copy was also corrected so that it
cannot reintroduce the non-portable generated C when used for historical
comparison.

## Regression coverage

`quality-assurance/cases/tools/io_int_roundtrip.CMOT` reads and writes the
64-bit value `922337203685477580`. Tool test `TOOL-0039` compiles emitted C with:

```sh
-std=c11 -Wall -Wextra -Werror=format
```

Tool test `TOOL-0040` then executes the strict-C11 output and verifies the exact
64-bit stream round trip. The object-I/O example and standard-library feature
fixture also exercise `OStream.WriteInt`.

## MIT license

The former abbreviated license notice was replaced by the complete canonical
MIT License grant, conditions, and warranty disclaimer in the repository-root
`LICENSE` file. The copyright notice is:

```text
Copyright (c) 2026 CMotive contributors
```

Tool test `TOOL-0128` now checks that release archives contain the complete MIT
License text, not merely a file named `LICENSE`.

## Full Linux verification

Command:

```sh
make -f Makefile.linux qa-all
```

Results:

```text
CMotive self-host fixed-point and behavior: PASS
CMotive QA summary: 1200 passed, 0 failed, 1200 manifest tests
Tool QA: PASS (128 tests)
CMotive tests: PASS
c2cmotive tests: PASS (3 fixtures, default paths, preserve mode, complete frontend migration)
CMotive examples: PASS (158 examples)
CMotive language files: PASS (312 files, 4 parallel jobs)
```

The stage-1, stage-2, and stage-3 generated frontend C files remain
byte-identical. Their SHA-256 is:

```text
bd9c5c7ce209d0119472506941b5ab7ff7fff08f1b0c1cdafc5638ae7df9addf
```

The converter's complete-frontend migration test still reports two previously
documented, non-fatal discarded-`const` qualifier warnings in its generated
native bridge. They are unrelated to integer stream formatting; converter
compilation and all behavior tests pass.

## Verification environment

```text
Linux 6.18.35 x86_64
GCC 14.2.0
GNU Make 4.4.1
```

Linux compilation and runtime verification were performed directly. The macOS
and native Visual Studio 2022 environments were not present on this host; their
build files and project integration remain covered by the static tool tests.

## Packaged-source verification

The release ZIP and TAR.GZ passed archive-integrity inspection, contained no
`build/`, `dist/`, or `.git/` output, and preserved the complete MIT License.
A fresh extraction of the ZIP was then built without using the working tree's
artifacts. The clean extracted source reported:

```text
CMotive self-host fixed-point and behavior: PASS
CMotive QA summary: 1200 passed, 0 failed, 1200 manifest tests
Tool QA: PASS (128 tests)
```
