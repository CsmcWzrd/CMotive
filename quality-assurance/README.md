# CMotive Quality Assurance Suite

This directory contains a deterministic, checked-in QA suite for the self-hosted CMotive frontend and all shipped command-line tools.

## Test inventory

The suite contains **1,200 newly catalogued tests**:

- 640 runtime language-semantics assertions (`LANG-*`)
- 192 preprocessor assertions (`PP-*`)
- 96 advanced language and standard-library assertions (`FEATURE-*`)
- 128 compiler/tool/packaging assertions (`TOOL-*`)
- 96 C-to-CMotive converter assertions (`CONVERT-*`)
- 48 expected-failure and diagnostic assertions (`NEG-*`)

The legacy conformance suite and all examples are additional regression layers and are run by `qa-all`. `manifest.tsv` is the authoritative case catalog; `coverage-matrix.tsv` maps language/tool areas to test ranges.

## Running

From the source root after building the tools:

```sh
make -f Makefile.linux qa
make -f Makefile.linux qa-all
```

Use `Makefile.mac` on macOS and `Makefile.windows` from a POSIX-compatible Windows shell. Native Visual Studio users can run `quality-assurance/run_qa.cmd` after `vs2022\build-selfhost.cmd`.

The runner writes machine-readable TSV results and a Markdown summary under `build/quality-assurance/`. Every manifest ID must be reported exactly once; missing, duplicate, or unknown result IDs fail the suite.

## Design

Runtime and advanced cases are grouped into executables for speed, but each internal assertion has its own stable manifest ID and explicit source marker. Preprocessor cases compare exact expected expanded lines. Converter cases verify both translated function presence and behavior after compiling the generated CMotive source. Negative cases require the expected diagnostic and status.
