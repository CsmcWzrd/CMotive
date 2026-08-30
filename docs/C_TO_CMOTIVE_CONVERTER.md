# `c2cmotive`: C to CMotive conversion

## Purpose

`c2cmotive` assists migration of existing C implementation files into CMotive.
The converter itself is implemented in CMotive at `src/tools/CToCMotive.CMOT`
and is compiled by the self-hosted frontend.

## Outputs

For one C input, the converter writes two files:

1. a `.CMOT` file containing converted function definitions;
2. a native support header containing includes, macros, typedefs, globals,
   declarations, variadic functions, and functions that require C
   preprocessor directives.

Example:

```sh
build/bin/c2cmotive \
  --verbose \
  -o build/migration/module.CMOT \
  --support build/migration/module_native.h \
  --include build/migration/module_native.h \
  source/module.c
```

The generated CMotive source begins with a `NativeInclude` declaration for the
support header.

## Conversion behavior

The converter currently:

- recognizes top-level C function definitions while respecting strings,
  character literals, comments, nested parentheses, and nested braces;
- maps common C scalar and fixed-width integer types to CMotive types;
- maps array parameters to pointers;
- removes C storage/qualifier words that do not belong in CMotive signatures;
- converts C control-flow spelling to CMotive spelling by default;
- preserves comments and string/character literals without keyword rewriting;
- leaves variadic and preprocessor-bearing functions in the native header;
- emits C prototypes and symbol aliases that let retained native functions call
  package-mangled converted functions;
- creates output directories as needed.

Use `--preserve-keywords` to retain lowercase C control-flow words. The
self-hosted frontend accepts this C-compatible body subset as well.

## Command-line options

```text
-o FILE              CMotive output (default: input.CMOT)
--support FILE       native header (default: input_native.h)
--include NAME       NativeInclude spelling (default: support path)
--preserve-keywords  keep lowercase C control-flow keywords
--verbose            print conversion counts
--version            print converter version
--help               print usage
```

## Native boundary policy

A retained support header is expected for C ABI constructs that CMotive cannot
yet represent directly. It should be reviewed after conversion and reduced as
CMotive gains the corresponding language features. The converter does not
claim that arbitrary platform-specific C can be made portable automatically.

Notable review cases include:

- top-level conditional-compilation regions that wrap entire function
  definitions;
- compiler extensions, attributes, and inline assembly;
- complex declarators such as function-pointer parameters;
- macro-generated declarations or functions;
- dependencies on C linkage visibility such as file-local `static` symbols;
- code whose correctness depends on `const`, `volatile`, or `restrict`
  diagnostics rather than runtime behavior.

## Verification

`scripts/run_converter_tests.sh` performs:

- three executable fixture conversions;
- default CMotive keyword conversion;
- keyword-preserving conversion;
- string and comment preservation checks;
- variadic native-helper retention;
- array/pointer conversion;
- preprocessing and compilation of every generated CMotive file;
- conversion of the complete stage-0 CMotive compiler seed;
- compilation of that converted frontend;
- compiler and preprocessor smoke tests using the converted frontend.

Run it with:

```sh
make -f Makefile.linux converter-test
```
