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
make -f Makefile.linux qa            # 1,200-case catalogued QA suite
make -f Makefile.linux qa-all        # QA plus self-host, legacy, examples, language sweep
make -f Makefile.linux examples      # preprocess, compile, and run 158 examples
make -f Makefile.linux language      # preprocess and compile-check every language file
make -f Makefile.linux verify-all    # alias for qa-all
```

The checked-in suite under `quality-assurance/` assigns a stable ID to every
case and covers runtime semantics, advanced object-oriented features, the
preprocessor, diagnostics, command-line behavior, debug symbols, release
packaging, and C-to-CMotive conversion.  Its manifest contains 1,200 tests;
the runner rejects missing, duplicated, or unrecognised result IDs and writes
machine-readable results under `build/quality-assurance/`.

Whole-tree language validation defaults to four parallel workers. Override it
with `CMOTIVE_VALIDATE_JOBS=<count>`.

## C and C++ interoperability

CMotive interoperates with native code through the platform C ABI. Direct C
interoperability is supported in both directions. C++ interoperability is
supported through `extern "C"` wrapper functions; CMotive does not directly
consume or expose the implementation-specific native C++ ABI.

| Direction | Supported path |
|---|---|
| CMotive to C | Include a C declaration with `NativeInclude`, then link a C object or library |
| C to CMotive | Compile CMotive with `-c`, declare the generated package-qualified C symbol, and link the object |
| CMotive to C++ | Export the required C++ behavior through an `extern "C"` wrapper |
| C++ to CMotive | Declare the CMotive-generated symbol inside `extern "C"` and link the CMotive object |
| CMotive to native C++ classes/templates | Not directly supported; use C ABI wrappers and opaque handles |

### Calling a C library from CMotive

Declare the native API in a C header:

```c
#ifndef C_MATH_H
#define C_MATH_H

#include <stdint.h>

int32_t c_add_i32(int32_t left, int32_t right);

#endif
```

Implement and compile the C library normally:

```c
#include "c_math.h"

int32_t c_add_i32(int32_t left, int32_t right)
{
    return left + right;
}
```

```sh
cc -std=c11 -c c_math.c -o c_math.o
```

Expose the declaration to CMotive with `NativeInclude`:

```text
NativeInclude "c_math.h";

Package Demo;

I32
main
()
{
    result : I32 = c_add_i32(20, 22);
    Return result == 42 ? 0 : 1;
}
```

Compile and link the native object with the CMotive program:

```sh
build/bin/cmotive \
  -I . \
  application.CMOT \
  c_math.o \
  -o application
```

A C static or shared library understood by the selected host toolchain can be
linked with the normal library search options:

```sh
build/bin/cmotive \
  -I include \
  -L lib \
  application.CMOT \
  -lcmath \
  -o application
```

The current driver accepts `.o` and `.obj` files as native positional inputs.
Compile `.c` and `.cpp` sources separately before invoking `cmotive`. Use
`-L`/`-l` for native libraries, or perform the final native link externally;
full `.a`, `.so`, `.dylib`, `.dll`, and `.lib` paths are not currently treated
as native positional inputs by the CMotive driver.

### Calling CMotive from C

Compile a CMotive module to an object file:

```text
Package Demo;

I32
AddPair
left : I32
right : I32
()
{
    Return left + right;
}
```

```sh
build/bin/cmotive -c module.CMOT -o module.o
```

Non-member CMotive functions are emitted with package-qualified C symbols. The
example above is exported as `Demo__AddPair`. A C caller can declare and call
that symbol directly:

```c
#include <stdint.h>
#include <stdio.h>

extern int32_t Demo__AddPair(int32_t left, int32_t right);

int main(void)
{
    int32_t result = Demo__AddPair(19, 23);
    printf("%d\n", (int)result);
    return result == 42 ? 0 : 1;
}
```

On a POSIX host, a typical external link is:

```sh
cc caller.c module.o -pthread -lm -o caller
```

Use the equivalent system libraries for the selected Windows or macOS
compiler. Package separators become double underscores, so
`Company::Product::Execute` is emitted as `Company__Product__Execute`. A
function with no explicit package uses the `StartPackage__` prefix. `main` is
the exception and remains the ordinary C symbol `main`.

Generated names can be inspected with either of these commands:

```sh
build/bin/cmotive --emit-c module.CMOT -o module.c
nm -g module.o
```

There is not yet an automatic public C-header generator, so public C
prototypes must currently be maintained manually. Package-qualified symbol
names and CMotive class layouts should be regarded as compiler ABI until a
formal CMotive ABI version is frozen.

### Calling a C++ library from CMotive

Do not expose C++ overloads, references, templates, standard-library classes,
or C++ object layouts directly. Provide a C-compatible wrapper header:

```c
#ifndef CPP_BRIDGE_H
#define CPP_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int32_t cpp_string_size_plus(const char *text, int32_t extra);

#ifdef __cplusplus
}
#endif

#endif
```

Implement the wrapper in C++. Catch exceptions inside the wrapper so no C++
exception crosses the C ABI boundary:

```cpp
#include "cpp_bridge.h"

#include <string>

extern "C" int32_t cpp_string_size_plus(
    const char *text,
    int32_t extra)
{
    try {
        const std::string value = text ? text : "";
        return static_cast<int32_t>(value.size()) + extra;
    } catch (...) {
        return -1;
    }
}
```

Call the wrapper from CMotive exactly as a C function:

```text
NativeInclude "cpp_bridge.h";

Package Demo;

I32
main
()
{
    result : I32 = cpp_string_size_plus("CMotive", 35);
    Return result == 42 ? 0 : 1;
}
```

Build the wrapper and link the matching C++ runtime. For a GCC/libstdc++
toolchain:

```sh
c++ -std=c++20 -c cpp_bridge.cpp -o cpp_bridge.o

build/bin/cmotive \
  -I . \
  application.CMOT \
  cpp_bridge.o \
  -lstdc++ \
  -o application
```

When the wrapper is built with Clang and libc++, use the matching libc++ link
option, normally `-lc++`, instead of `-lstdc++`.

For native C++ objects, expose an opaque handle rather than the C++ object
layout:

```c
typedef void *CppWidgetHandle;

CppWidgetHandle cpp_widget_create(void);
int32_t cpp_widget_execute(CppWidgetHandle handle);
void cpp_widget_destroy(CppWidgetHandle handle);
```

CMotive can carry such a handle as `Void*`. The create, operation, and destroy
functions remain implemented by the C++ wrapper.

### Calling CMotive from C++

C++ callers must suppress C++ name mangling for CMotive-generated symbols:

```cpp
#include <cstdint>
#include <iostream>

extern "C" std::int32_t Demo__AddPair(
    std::int32_t left,
    std::int32_t right);

int main()
{
    const auto result = Demo__AddPair(30, 12);
    std::cout << result << '\n';
    return result == 42 ? 0 : 1;
}
```

Link the C++ caller with the CMotive object:

```sh
c++ -std=c++20 caller.cpp module.o -pthread -lm -o caller
```

### Recommended ABI type mappings

Use fixed-width types at public language boundaries whenever possible:

| CMotive type | C/C++ ABI type |
|---|---|
| `I16` / `Int16` | `int16_t` |
| `I32` / `Int32` | `int32_t` |
| `I64` / `Int` | `int64_t` |
| `U16` / `Uint16` | `uint16_t` |
| `U32` / `Uint32` | `uint32_t` |
| `U64` / `Uint` | `uint64_t` |
| `Float` | `float` |
| `Double` | `double` |
| `Ldouble` | `long double` |
| `Boolean` / `Bool` | `int` |
| `Char` | `char` |
| `Char*` | `char *` |
| `Char16` | `uint16_t` |
| `Char32` | `uint32_t` |
| `Void*` | `void *` |

At a public ABI boundary, prefer fixed-width integers, pointers plus explicit
lengths, plain C structures with documented layout, and opaque handles. Memory
allocated by one library should normally be released by an exported function
from that same library, especially across Windows C runtime boundaries.

The current `Extern` keyword is accepted as a language decorator, but it is not
yet a complete foreign-function declaration mechanism: it does not currently
provide declaration-only imports, unmangled external-name selection, C versus
C++ linkage selection, or calling-convention control. Use `NativeInclude` for
foreign declarations.

CMotive classes lower to C structures and package-qualified functions, but
their field layout, construction rules, virtual dispatch representation, and
lifecycle ABI are not yet frozen for direct cross-language object sharing.
Expose primitive-value wrapper functions or opaque handles instead of passing
CMotive class instances directly to C or C++.


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
- `quality-assurance/README.md` — 1,200-case suite inventory and execution
- `VERIFY_SELFHOST_FRONTEND.md` — exact verification results for this release
- `VERIFY_RUNTIME_IO_MIT_LICENSE.md` — portable 64-bit I/O and MIT-license verification

## License

CMotive is distributed under the MIT License. See `LICENSE` for the complete license text.
