

#  Interoperability direction	Current status
CMotive → C	Supported directly through the C ABI
C → CMotive	Supported by linking CMotive object files and calling exported symbols
CMotive → C++	Supported through an extern "C" wrapper
C++ → CMotive	Supported by declaring CMotive symbols as extern "C"
CMotive → native C++ classes/templates	Not directly supported

I verified all four supported directions against the current v0.3.0-selfhost package on Linux.

Calling a C library from CMotive

CMotive can include a native C declaration using NativeInclude, then link either a C object file or a library through -L and -l.
```
C header
#ifndef C_MATH_H
#define C_MATH_H

#include <stdint.h>

int32_t c_add_i32(int32_t left, int32_t right);

#endif
C implementation
#include "c_math.h"

int32_t c_add_i32(int32_t left, int32_t right)
{
    return left + right;
}
CMotive application
NativeInclude "c_math.h";

Package Demo;

I32
main
()
{
    result : I32 = c_add_i32(20, 22);

    Return result == 42 ? 0 : 1;
}

Build it with:

cc -c c_math.c -o c_math.o

build/bin/cmotive \
    -I . \
    application.CMOT \
    c_math.o \
    -o application

A static or shared C library can instead be linked with:

build/bin/cmotive \
    -I include \
    -L lib \
    application.CMOT \
    -lcmath \
    -o application

The current compiler supports:

-I <include-directory>
-L <library-directory>
-l <library-name>
.o
.obj
```


C and C++ source files must currently be compiled separately. Passing a .c or .cpp file directly to cmotive is not supported because an unrecognized positional file is treated as CMotive source.

Similarly, full .a, .so, .dylib, .dll, or .lib paths are not currently recognized as native positional inputs. Use -L/-l, pass an object file, or perform the final link externally.


```
Calling CMotive from C

Compile the CMotive source as a native object file:

Package Demo;

I32
AddPair
left : I32
right : I32
()
{
    Return left + right;
}
build/bin/cmotive -c module.CMOT -o module.o

Non-member CMotive functions use package-qualified C symbols. The function above is exported as:

Demo__AddPair

A C application can call it directly:

#include <stdint.h>
#include <stdio.h>

extern int32_t Demo__AddPair(int32_t left, int32_t right);

int main(void)
{
    int32_t result = Demo__AddPair(19, 23);
    printf("%d\n", (int)result);
    return result == 42 ? 0 : 1;
}

Link it with:

cc caller.c module.o -pthread -lm -o caller

This test produced:

42

For a nested package such as:

Package Company::Product;

a function named Execute is currently exported as:

Company__Product__Execute

The main function is the exception: it remains the ordinary C symbol main.

You can inspect generated names using:

build/bin/cmotive --emit-c module.CMOT -o module.c

or:

nm -g module.o
```


There is not yet an automatic public C-header generator, so external prototypes must currently be written manually.


```
Calling a C++ library from CMotive

CMotive does not directly understand the native C++ ABI, including:

C++ name mangling;
overloaded functions;
references;
templates;
classes and member functions;
std::string, std::vector, and other standard-library types;
C++ exceptions;
implementation-specific object layouts.

Expose the required C++ functionality through a C ABI wrapper.

Wrapper header
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
Wrapper implementation
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
CMotive caller
NativeInclude "cpp_bridge.h";

Package Demo;

I32
main
()
{
    result : I32 =
        cpp_string_size_plus("CMotive", 35);

    Return result == 42 ? 0 : 1;
}

Build and link on Linux with GCC:

g++ -std=c++20 -c cpp_bridge.cpp -o cpp_bridge.o

build/bin/cmotive \
    -I . \
    application.CMOT \
    cpp_bridge.o \
    -lstdc++ \
    -o application

For Clang with libc++, the corresponding runtime library is normally:

-lc++

The wrapper should catch all C++ exceptions. A C++ exception must not cross an extern "C" boundary.

For C++ objects, expose an opaque handle:

typedef void *CppWidgetHandle;

CppWidgetHandle cpp_widget_create(void);
int32_t cpp_widget_execute(CppWidgetHandle handle);
void cpp_widget_destroy(CppWidgetHandle handle);

CMotive can represent the handle as Void*.
```



Calling CMotive from C++


```
A C++ application must prevent the C++ compiler from applying C++ name mangling to the imported CMotive symbol:

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

Build it with:

g++ -std=c++20 caller.cpp module.o -pthread -lm -o caller

This direction was also verified and produced:

42
Type mappings at the ABI boundary

The safest mappings are:

CMotive	C/C++ ABI type
I16 / Int16	int16_t
I32 / Int32	int32_t
I64 / Int	int64_t
U16 / Uint16	uint16_t
U32 / Uint32	uint32_t
U64 / Uint	uint64_t
Float	float
Double	double
Ldouble	long double
Char	char
Char*	char *
Void*	void *
Boolean / Bool	int

```


For public interoperation, fixed-width integer types, pointers, opaque handles, and plain C structures are preferable.

Memory allocated by one library should normally be released by an exported function from the same library, particularly across Windows CRT boundaries.

Current limitations
```
The current Extern keyword is accepted as a language decorator, but it is not yet a complete foreign-function declaration mechanism. In particular, it does not currently:

preserve an unmangled external C name;
create a declaration-only function automatically;
suppress CMotive function-body generation;
specify calling conventions;
distinguish extern "C" from native C++ linkage.

For current FFI work, use:

NativeInclude "native_api.h";

rather than relying on Extern.

CMotive classes also generate callable C symbols such as:

Package__Class__Method
Package__Class__ctor
Package__Class__dtor
Package__Class__new
Package__Class__delete

```

However, directly sharing CMotive class instances with C or C++ is not presently recommended. The object layout includes compiler-managed fields, virtual-dispatch details, constructor conventions, and an ABI that has not yet been formally frozen. A plain CMotive wrapper function that accepts primitive values or opaque pointers is safer.

Therefore, the accurate answer is: CMotive has working bidirectional C ABI interoperability now; C++ interoperability works reliably through C-compatible wrapper functions, but native C++ ABI interoperability is not yet implemented.
