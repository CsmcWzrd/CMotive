# c2cmotive conversion tests

These fixtures exercise fixed-width and native C type mapping, arrays and
pointers, comments/strings, brace-less control flow, native variadic helpers,
global ABI declarations, and executable C -> CMotive -> native round trips.

The test runner also converts the complete stage-0 compiler seed, compiles the
converted CMotive frontend, and uses that converted frontend for compiler and
preprocessor smoke tests.
