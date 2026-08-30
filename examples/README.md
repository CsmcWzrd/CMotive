# CMotive language examples

This directory contains 158 runnable CMotive examples together with helper
headers and packages. The examples are part of the main source archive and use
the self-hosted CMotive compiler and preprocessor from `build/bin/`.

From the repository root:

```sh
make -f makefile.examples.linux examples
make -f makefile.examples.linux language
```

The platform equivalents are:

```text
makefile.examples.mac
makefile.examples.windows
```

`examples` preprocesses, compiles, and executes every `.CMOT`/`.CMTV` example.
`language` preprocesses and compile-checks every `.CMOT`, `.CMTV`, `.HMOT`, and
`.HMTV` file in the source tree. Set `CMOTIVE_VALIDATE_JOBS` to control the
parallel language-file validation worker count.

Coverage includes scalar and pointer types, operators, control flow, classes,
inheritance, constructors/destructors, `New`/`Delete`, templates, blend/enum
syntax, exceptions, packages/plugins, `Sys::IO`, STL-style containers,
algorithms, sockets, threading, dynamic structs, package globals, function
pointers, overridable methods, target/hit dispatch, debug metadata, and
object-oriented `Sys::*` APIs.
