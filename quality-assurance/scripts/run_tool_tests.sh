#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
BIN_DIR=${1:-"$ROOT/build/bin"}
EXEEXT=${2:-}
RESULTS=${3:-"$ROOT/build/quality-assurance/tool-results.tsv"}
WORK=${4:-"$ROOT/build/quality-assurance/tool-work"}
CC_CMD=${CC:-cc}

case "$BIN_DIR" in /*) ;; *) BIN_DIR="$ROOT/$BIN_DIR" ;; esac
case "$RESULTS" in /*) ;; *) RESULTS="$ROOT/$RESULTS" ;; esac
case "$WORK" in /*) ;; *) WORK="$ROOT/$WORK" ;; esac

CMOTIVE="$BIN_DIR/cmotive$EXEEXT"
CMOTIVEPLUS="$BIN_DIR/cmotive++$EXEEXT"
CMOTIVEPP="$BIN_DIR/cmotivepp$EXEEXT"
CMOTIVESYMS="$BIN_DIR/CMotiveSymsToDebugFile$EXEEXT"
C2CMOTIVE="$BIN_DIR/c2cmotive$EXEEXT"
TOOLS="$ROOT/quality-assurance/cases/tools"
PP="$ROOT/quality-assurance/cases/preprocessor"

rm -rf "$WORK"
mkdir -p "$WORK" "$(dirname -- "$RESULTS")"
: > "$RESULTS"
NEXT=1
FAILURES=0

record_result() {
    status=$1
    desc=$2
    id=$(printf 'TOOL-%04d' "$NEXT")
    printf '%s\t%s\t%s\n' "$id" "$status" "$desc" >> "$RESULTS"
    if [ "$status" = PASS ]; then
        printf 'PASS %s %s\n' "$id" "$desc"
    else
        printf 'FAIL %s %s\n' "$id" "$desc" >&2
        FAILURES=$((FAILURES + 1))
    fi
    NEXT=$((NEXT + 1))
}

check() {
    desc=$1
    shift
    if "$@"; then record_result PASS "$desc"; else record_result FAIL "$desc"; fi
}

check_sh() {
    desc=$1
    expr=$2
    if sh -c "$expr"; then record_result PASS "$desc"; else record_result FAIL "$desc"; fi
}

capture() {
    name=$1
    shift
    set +e
    "$@" > "$WORK/$name.out" 2> "$WORK/$name.err"
    rc=$?
    set +e
    printf '%s\n' "$rc" > "$WORK/$name.status"
    return 0
}

export ROOT BIN_DIR EXEEXT RESULTS WORK CC_CMD CMOTIVE CMOTIVEPLUS CMOTIVEPP CMOTIVESYMS C2CMOTIVE TOOLS PP

# TOOL-0001..TOOL-0016: installed binaries, versions and required diagnostics.
check "cmotive executable is present" test -x "$CMOTIVE"
check "cmotive++ executable is present" test -x "$CMOTIVEPLUS"
check "cmotivepp executable is present" test -x "$CMOTIVEPP"
check "CMotiveSymsToDebugFile executable is present" test -x "$CMOTIVESYMS"
check "c2cmotive executable is present" test -x "$C2CMOTIVE"
capture cmotive-version "$CMOTIVE" --version
check "cmotive --version exits successfully" grep -qx 0 "$WORK/cmotive-version.status"
check "cmotive reports the self-hosted compiler version" grep -Fq 'CMotive compiler 0.3.0-selfhost' "$WORK/cmotive-version.out"
capture cmotiveplus-version "$CMOTIVEPLUS" --version
check "cmotive++ reports the same compiler version" cmp -s "$WORK/cmotive-version.out" "$WORK/cmotiveplus-version.out"
capture converter-version "$C2CMOTIVE" --version
check "c2cmotive reports its self-hosted version" grep -Fq 'c2cmotive 0.3.0-selfhost' "$WORK/converter-version.out"
capture converter-help "$C2CMOTIVE" --help
check "c2cmotive --help exits successfully" grep -qx 0 "$WORK/converter-help.status"
check "c2cmotive help documents the output option" grep -Fq -- '-o FILE' "$WORK/converter-help.out"
check "c2cmotive help documents the support-header option" grep -Fq -- '--support FILE' "$WORK/converter-help.out"
capture no-input "$CMOTIVE"
check "cmotive without input returns status 2" grep -qx 2 "$WORK/no-input.status"
check "cmotive without input emits a diagnostic" grep -Fq 'no input files' "$WORK/no-input.err"
capture pp-no-input "$CMOTIVEPP"
check "cmotivepp without input returns status 2" grep -qx 2 "$WORK/pp-no-input.status"
check "cmotivepp without input emits a diagnostic" grep -Fq 'no input' "$WORK/pp-no-input.err"

# TOOL-0017..TOOL-0032: driver identity, target reporting and root discovery.
capture linker "$CMOTIVE" --print-linker
check "--print-linker exits successfully" grep -qx 0 "$WORK/linker.status"
check "--print-linker returns a nonempty linker command" test -s "$WORK/linker.out"
capture toolchain "$CMOTIVE" --print-toolchain
check "--print-toolchain exits successfully" grep -qx 0 "$WORK/toolchain.status"
check "toolchain report contains the C compiler" grep -Fq 'cc=' "$WORK/toolchain.out"
check "toolchain report contains the linker" grep -Fq 'ld=' "$WORK/toolchain.out"
capture target-native "$CMOTIVE" --print-target-arch
check "default target architecture is native" grep -qx native "$WORK/target-native.out"
capture target-x64 "$CMOTIVE" --target-arch x64 --print-target-arch
check "x64 target selection round-trips" grep -qx x64 "$WORK/target-x64.out"
capture target-x86_64 "$CMOTIVE" --target-arch x86_64 --print-target-arch
check "x86_64 target selection round-trips" grep -qx x86_64 "$WORK/target-x86_64.out"
capture target-arm64 "$CMOTIVE" --target-arch arm64 --print-target-arch
check "arm64 target selection round-trips" grep -qx arm64 "$WORK/target-arm64.out"
check "cmotive++ is the same frontend binary" cmp -s "$CMOTIVE" "$CMOTIVEPLUS"
check "cmotivepp is the same multi-call frontend binary" cmp -s "$CMOTIVE" "$CMOTIVEPP"
check "CMotiveSymsToDebugFile is the same multi-call frontend binary" cmp -s "$CMOTIVE" "$CMOTIVESYMS"
capture cmotive-version-2 "$CMOTIVE" --version
check "version output is deterministic" cmp -s "$WORK/cmotive-version.out" "$WORK/cmotive-version-2.out"
check_sh "frontend discovers its source root outside the working directory" 'cd / && "$CMOTIVE" "$TOOLS/smoke.CMOT" -o "$WORK/nested-root" >/dev/null 2>&1 && "$WORK/nested-root"'
check_sh "compiler accepts an uppercase CMOT source extension" '"$CMOTIVE" "$TOOLS/smoke.CMOT" -o "$WORK/uppercase-ext" >/dev/null 2>&1 && "$WORK/uppercase-ext"'
check_sh "compiler accepts a lowercase cmot source extension" '"$CMOTIVE" "$TOOLS/lowercase.cmot" -o "$WORK/lowercase-ext" >/dev/null 2>&1 && "$WORK/lowercase-ext"'

# TOOL-0033..TOOL-0064: compiler modes, code generation, optimization and linking.
capture compile-smoke "$CMOTIVE" "$TOOLS/smoke.CMOT" -o "$WORK/smoke-bin"
check "normal compile-and-link mode exits successfully" grep -qx 0 "$WORK/compile-smoke.status"
check "normal compile-and-link mode creates the requested executable" test -x "$WORK/smoke-bin"
check "compiled CMotive executable returns success" "$WORK/smoke-bin"
capture custom-output "$CMOTIVE" "$TOOLS/lowercase.cmot" -o "$WORK/exact-output-name"
check "-o writes the exact requested output path" test -x "$WORK/exact-output-name"
capture emit-c "$CMOTIVE" --emit-c "$TOOLS/smoke.CMOT" -o "$WORK/smoke-generated.c"
check "--emit-c exits successfully" grep -qx 0 "$WORK/emit-c.status"
check "--emit-c identifies generated CMotive C" grep -Fq 'Generated by the CMotive frontend' "$WORK/smoke-generated.c"
capture strict-c "$CC_CMD" -std=c11 -I"$ROOT" -I"$ROOT/lib/Sys" "$WORK/smoke-generated.c" -pthread -lm -o "$WORK/strict-c-bin"
check "emitted C compiles in strict C11 mode" grep -qx 0 "$WORK/strict-c.status"
check "strict-C11 compiled output executes successfully" "$WORK/strict-c-bin"
capture object-mode "$CMOTIVE" -c "$TOOLS/smoke.CMOT" -o "$WORK/smoke.o"
check "-c object-only mode exits successfully" grep -qx 0 "$WORK/object-mode.status"
check "-c object-only mode creates a nonempty object" test -s "$WORK/smoke.o"
capture keep-c "$CMOTIVE" --keep-c "$TOOLS/smoke.CMOT" -o "$WORK/keep-bin"
check "--keep-c compile-and-link mode exits successfully" grep -qx 0 "$WORK/keep-c.status"
check "--keep-c preserves output-path.c" test -s "$WORK/keep-bin.c"
check "preserved --keep-c source is generated CMotive C" grep -Fq 'Generated by the CMotive frontend' "$WORK/keep-bin.c"
capture debug1 "$CMOTIVE" -g "$TOOLS/smoke.CMOT" -o "$WORK/debug1"
check "-g build exits successfully" grep -qx 0 "$WORK/debug1.status"
check "-g build creates JSON debug metadata" test -s "$WORK/debug1.cmotive.debug.json"
check "-g build creates CMotive symbol metadata" test -s "$WORK/debug1_cmot_debugsymbols.syms"
check "-g metadata records debug level 1" grep -Fq '"debug_level": 1' "$WORK/debug1.cmotive.debug.json"
check "-g symbol file records debug level 1" grep -Fq 'debug_level: 1' "$WORK/debug1_cmot_debugsymbols.syms"
capture debug2 "$CMOTIVE" -g2 "$TOOLS/smoke.CMOT" -o "$WORK/debug2"
check "-g2 metadata records debug level 2" grep -Fq '"debug_level": 2' "$WORK/debug2.cmotive.debug.json"
capture debug3 "$CMOTIVE" -g3 "$TOOLS/smoke.CMOT" -o "$WORK/debug3"
check "-g3 metadata records debug level 3" grep -Fq '"debug_level": 3' "$WORK/debug3.cmotive.debug.json"
capture opt0 "$CMOTIVE" -g -O0 "$TOOLS/lowercase.cmot" -o "$WORK/opt0"
check "-O0 is passed through and recorded" grep -Fq '"optimization": "O0"' "$WORK/opt0.cmotive.debug.json"
capture opt1 "$CMOTIVE" -g -O1 "$TOOLS/lowercase.cmot" -o "$WORK/opt1"
check "-O1 is passed through and recorded" grep -Fq '"optimization": "O1"' "$WORK/opt1.cmotive.debug.json"
capture opt2 "$CMOTIVE" -g -O2 "$TOOLS/lowercase.cmot" -o "$WORK/opt2"
check "-O2 is passed through and recorded" grep -Fq '"optimization": "O2"' "$WORK/opt2.cmotive.debug.json"
capture opt3 "$CMOTIVE" -g -O3 "$TOOLS/lowercase.cmot" -o "$WORK/opt3"
check "-O3 is passed through and recorded" grep -Fq '"optimization": "O3"' "$WORK/opt3.cmotive.debug.json"
capture opts "$CMOTIVE" -g -Os "$TOOLS/lowercase.cmot" -o "$WORK/opts"
check "-Os is passed through and recorded" grep -Fq '"optimization": "Os"' "$WORK/opts.cmotive.debug.json"
check "debug symbols include a free-function prototype" grep -Fq 'StartPackage::QaToolAdd(a: I32, b: I32)' "$WORK/debug1_cmot_debugsymbols.syms"
check "debug symbols include a class-method prototype" grep -Fq 'QaToolClass::GetValue(' "$WORK/debug1_cmot_debugsymbols.syms"
check_sh "debug symbol output excludes main" '! grep -Fq "::main(" "$WORK/debug1_cmot_debugsymbols.syms"'
capture emit-target "$CMOTIVE" --emit-c --target-arch x64 "$TOOLS/lowercase.cmot" -o "$WORK/target-x64.c"
check "--emit-c accepts an explicit target architecture" grep -qx 0 "$WORK/emit-target.status"
check "emitted C records the selected target architecture" grep -Fq 'target-arch: x64' "$WORK/target-x64.c"
check_sh "multiple CMotive inputs are combined and linked" '"$CMOTIVE" "$TOOLS/multi_helper.CMOT" "$TOOLS/multi_main.CMOT" -o "$WORK/multi-bin" >/dev/null 2>&1 && "$WORK/multi-bin"'
check_sh "native object, include, library-dir and library options link successfully" '"$CC_CMD" -std=c11 -I"$TOOLS" -c "$TOOLS/native_api.c" -o "$WORK/native_api.o" && "$CMOTIVE" -I "$TOOLS" -L"$WORK" -lm "$TOOLS/native_link.CMOT" "$WORK/native_api.o" -o "$WORK/native-link" >/dev/null 2>&1 && "$WORK/native-link"'

# TOOL-0065..TOOL-0080: preprocessor standalone and compiler-integrated behavior.
capture pp-stdout "$CMOTIVEPP" "$PP/pp_01.CMOT"
check "cmotivepp writes expanded source to stdout" grep -qx 0 "$WORK/pp-stdout.status"
check "Replace directives expand in stdout mode" grep -Fq 'p0: I32 = 101;' "$WORK/pp-stdout.out"
capture pp-file "$CMOTIVEPP" "$PP/pp_01.CMOT" -o "$WORK/pp_01.out"
check "cmotivepp -o exits successfully" grep -qx 0 "$WORK/pp-file.status"
check "cmotivepp -o creates the requested output file" test -s "$WORK/pp_01.out"
capture pp-defs "$CMOTIVEPP" -DQA_CMD_9_6=96 -D QA_CMD_9_7=97 "$PP/pp_09.CMOT"
check "#define directives expand" grep -Fq 'p0: I32 = 90;' "$WORK/pp-defs.out"
check "#undef permits the later Replace fallback" grep -Fq 'p4: I32 = 95;' "$WORK/pp-defs.out"
check "joined -DNAME=VALUE definitions expand" grep -Fq 'p6: I32 = 96;' "$WORK/pp-defs.out"
check "split -D NAME=VALUE definitions expand" grep -Fq 'p7: I32 = 97;' "$WORK/pp-defs.out"
capture pp-include "$CMOTIVEPP" "$PP/pp_13.CMOT"
check "quoted include paths resolve relative to the source file" grep -Fq 'p0: I32 = 1300;' "$WORK/pp-include.out"
capture pp-plugin-joined "$CMOTIVEPP" -I"$PP/plugins" "$PP/pp_23.CMOT"
check "joined -I path resolves a Plugin source" grep -Fq 'QaPluginValue0' "$WORK/pp-plugin-joined.out"
capture pp-plugin-split "$CMOTIVEPP" -I "$PP/plugins" "$PP/pp_24.CMOT"
check "split -I path resolves a Plugin source" grep -Fq 'QaPluginValue7' "$WORK/pp-plugin-split.out"
check "nested includes expose values from the second include level" grep -Fq 'p7: I32 = 1307;' "$WORK/pp-include.out"
capture pp-switch "$CMOTIVEPP" "$PP/pp_17.CMOT"
check "Plugswitch DEFINED comparison selects the matching case" grep -Fq 'QaSwitch0: I32 = 1;' "$WORK/pp-switch.out"
capture pp-platform "$CMOTIVEPP" "$PP/pp_21.CMOT"
check "Plugswitch OS selection emits a supported platform branch" grep -Fq 'QaPlatform0: I32 = 1;' "$WORK/pp-platform.out"
check "Plugswitch PROCESSOR and ENDIAN selections emit supported branches" grep -Fq 'QaPlatform6: I32 = 1;' "$WORK/pp-platform.out"
check_sh "compiler-integrated preprocessing resolves Plugin input" '"$CMOTIVE" -I "$PP/plugins" "$PP/pp_23.CMOT" -o "$WORK/pp-plugin-bin" >/dev/null 2>&1 && "$WORK/pp-plugin-bin"'

# TOOL-0081..TOOL-0096: standalone and compiler-generated symbol metadata.
rm -f "$WORK/cmotive_debugsymbols.syms"
check_sh "symbol tool accepts an empty invocation" 'cd "$WORK" && "$CMOTIVESYMS"'
check "symbol tool empty invocation creates its default output" test -s "$WORK/cmotive_debugsymbols.syms"
capture syms-custom "$CMOTIVESYMS" "$WORK/smoke-bin" -o "$WORK/custom.syms"
check "symbol tool accepts a binary and custom output path" grep -qx 0 "$WORK/syms-custom.status"
check "symbol tool creates the custom symbol file" test -s "$WORK/custom.syms"
check "standalone symbol file has the CMotive header" grep -Fq 'CMotive debug symbols' "$WORK/custom.syms"
check "standalone symbol file records the binary path" grep -Fq "binary: $WORK/smoke-bin" "$WORK/custom.syms"
check "standalone symbol file records debug level 0" grep -Fq 'debug_level: 0' "$WORK/custom.syms"
check "standalone symbol file contains an optimization field" grep -Fq 'optimization:' "$WORK/custom.syms"
check "standalone symbol file contains a 64-bit-style offset field" grep -Fq '0x00000000' "$WORK/custom.syms"
capture syms-metadata "$CMOTIVESYMS" "$WORK/smoke-bin" --metadata "$WORK/debug1.cmotive.debug.json" -o "$WORK/metadata.syms"
check "symbol tool accepts the --metadata companion option" grep -qx 0 "$WORK/syms-metadata.status"
check "--metadata argument is not mistaken for the binary" grep -Fq "binary: $WORK/smoke-bin" "$WORK/metadata.syms"
check "compiler symbol filename uses the required suffix" test -f "$WORK/debug1_cmot_debugsymbols.syms"
check "compiler JSON metadata declares its format" grep -Fq 'CMotive debug metadata v1' "$WORK/debug1.cmotive.debug.json"
check_sh "compiler JSON metadata has opening and closing braces" 'head -n 1 "$WORK/debug1.cmotive.debug.json" | grep -qx "{" && tail -n 1 "$WORK/debug1.cmotive.debug.json" | grep -qx "}"'
check "compiler symbols retain parameter names and types" grep -Fq 'a: I32, b: I32' "$WORK/debug1_cmot_debugsymbols.syms"
check_sh "compiler symbols omit constructors and destructors" '! grep -E "__(ctor|dtor)" "$WORK/debug1_cmot_debugsymbols.syms" >/dev/null'

# TOOL-0097..TOOL-0112: C-to-CMotive command-line conversion workflow.
capture c2-custom "$C2CMOTIVE" "$TOOLS/tool_converter.c" -o "$WORK/tool_converter.CMOT" --support "$WORK/tool_converter_support.h"
check "c2cmotive custom-output conversion exits successfully" grep -qx 0 "$WORK/c2-custom.status"
check "c2cmotive creates the requested CMotive source" test -s "$WORK/tool_converter.CMOT"
check "c2cmotive creates the requested native support header" test -s "$WORK/tool_converter_support.h"
check "generated CMotive source declares StartPackage" grep -Fq 'Package StartPackage;' "$WORK/tool_converter.CMOT"
check "generated CMotive source includes its support header" grep -Fq 'NativeInclude' "$WORK/tool_converter.CMOT"
check "generated CMotive source contains converted functions" grep -Fq 'func qa_converter_square' "$WORK/tool_converter.CMOT"
check "generated support header bridges retained main to converted functions" grep -Fq '#define qa_converter_square StartPackage__qa_converter_square' "$WORK/tool_converter_support.h"
capture c2-verbose "$C2CMOTIVE" --verbose "$TOOLS/tool_converter.c" -o "$WORK/verbose.CMOT" --support "$WORK/verbose.h"
check "c2cmotive --verbose exits successfully" grep -qx 0 "$WORK/c2-verbose.status"
check "c2cmotive --verbose reports conversion counts" grep -Fq 'converted' "$WORK/c2-verbose.out"
capture c2-include "$C2CMOTIVE" --include qa_custom_support.h "$TOOLS/tool_converter.c" -o "$WORK/include.CMOT" --support "$WORK/include.h"
check "--include controls the NativeInclude spelling" grep -Fq 'NativeInclude "qa_custom_support.h";' "$WORK/include.CMOT"
capture c2-preserve "$C2CMOTIVE" --preserve-keywords "$TOOLS/tool_converter.c" -o "$WORK/preserve.CMOT" --support "$WORK/preserve.h"
check "--preserve-keywords retains lowercase C control flow" grep -Fq 'if (' "$WORK/preserve.CMOT"
check "default conversion maps C control flow to CMotive spelling" grep -Fq 'If (' "$WORK/tool_converter.CMOT"
mkdir -p "$WORK/default-converter"
cp "$TOOLS/tool_converter.c" "$WORK/default-converter/default_case.c"
check_sh "converter creates the default .CMOT path" 'cd "$WORK/default-converter" && "$C2CMOTIVE" default_case.c >/dev/null 2>&1 && test -s default_case.CMOT'
check "converter creates the default _native.h support path" test -s "$WORK/default-converter/default_case_native.h"
capture c2-compile "$CMOTIVE" -I "$WORK" "$WORK/tool_converter.CMOT" -o "$WORK/tool-converted-bin"
check "converted CMotive source compiles with the self-hosted frontend" grep -qx 0 "$WORK/c2-compile.status"
check_sh "converted executable preserves the original C behavior" '"$WORK/tool-converted-bin" | grep -Fq "PASS TOOL CONVERTER"'

# TOOL-0113..TOOL-0128: repository scripts, build integration, manifest and packaging.
check "legacy conformance runner has valid POSIX-shell syntax" sh -n "$ROOT/scripts/run_tests.sh"
check "legacy converter runner has valid POSIX-shell syntax" sh -n "$ROOT/scripts/run_converter_tests.sh"
check "example runner has valid POSIX-shell syntax" sh -n "$ROOT/scripts/run_examples.sh"
check "language-file validator has valid POSIX-shell syntax" sh -n "$ROOT/scripts/validate_language_files.sh"
check "self-host verifier has valid POSIX-shell syntax" sh -n "$ROOT/scripts/verify_selfhost.sh"
check "release packager has valid POSIX-shell syntax" sh -n "$ROOT/scripts/package_release.sh"
check "release-candidate cutter has valid POSIX-shell syntax" sh -n "$ROOT/scripts/cut_rc.sh"
check "GA promotion script has valid POSIX-shell syntax" sh -n "$ROOT/scripts/promote_ga.sh"
check "quality-assurance orchestrator has valid POSIX-shell syntax" sh -n "$ROOT/quality-assurance/run_qa.sh"
check_sh "Linux Makefile exposes a parseable qa target" 'cd "$ROOT" && make -f Makefile.linux -n qa >/dev/null'
check_sh "macOS Makefile exposes a parseable qa target" 'cd "$ROOT" && make -f Makefile.mac -n qa >/dev/null'
check_sh "Windows Makefile exposes a parseable qa target" 'cd "$ROOT" && make -f Makefile.windows -n qa >/dev/null'
check "Visual Studio project retains the self-hosted frontend source" grep -Fq 'CMotiveFrontend.CMOT' "$ROOT/vs2022/CMotive.SelfHostedFrontend.vcxproj"
check_sh "QA manifest contains exactly 1200 tests" 'test "$(awk -F "\t" "NR>1{n++} END{print n+0}" "$ROOT/quality-assurance/manifest.tsv")" -eq 1200'
check_sh "QA manifest contains no duplicate IDs" 'test "$(tail -n +2 "$ROOT/quality-assurance/manifest.tsv" | cut -f1 | sort | uniq -d | wc -l | tr -d " ")" -eq 0'
check_sh "release packaging preserves the QA manifest" 'rm -rf "$WORK/package" && mkdir -p "$WORK/package" && sh "$ROOT/scripts/package_release.sh" --root "$ROOT" --out "$WORK/package" >/dev/null && archive=$(find "$WORK/package" -name "*.tar.gz" | head -n 1) && test -s "$archive" && tar -tzf "$archive" | grep -Fq "/quality-assurance/manifest.tsv"'

if [ "$NEXT" -ne 129 ]; then
    printf 'tool QA internal error: emitted %d tests, expected 128\n' "$((NEXT - 1))" >&2
    exit 2
fi
if [ "$FAILURES" -ne 0 ]; then
    printf 'Tool QA failures: %d\n' "$FAILURES" >&2
    exit 1
fi
printf 'Tool QA: PASS (128 tests)\n'
