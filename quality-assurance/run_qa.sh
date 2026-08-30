#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BIN_DIR=${1:-"$ROOT/build/bin"}
EXEEXT=${2:-}
case "$BIN_DIR" in /*) ;; *) BIN_DIR="$ROOT/$BIN_DIR" ;; esac

CMOTIVE="$BIN_DIR/cmotive$EXEEXT"
CMOTIVEPP="$BIN_DIR/cmotivepp$EXEEXT"
C2CMOTIVE="$BIN_DIR/c2cmotive$EXEEXT"
QA="$ROOT/quality-assurance"
OUT="$ROOT/build/quality-assurance"
WORK="$OUT/work"
LOGS="$OUT/logs"
RESULTS="$OUT/results.tsv"
SUMMARY="$OUT/summary.md"
MANIFEST="$QA/manifest.tsv"
CC_CMD=${CC:-cc}

rm -rf "$OUT"
mkdir -p "$WORK" "$LOGS"
printf 'id\tstatus\tdetail\n' > "$RESULTS"
FAILURES=0
START=$(date +%s 2>/dev/null || printf 0)

record() {
    id=$1
    status=$2
    # All runner-generated details are single-line literals. Avoid spawning
    # two filter processes for every one of the 1,200 result rows.
    detail=$3
    printf '%s\t%s\t%s\n' "$id" "$status" "$detail" >> "$RESULTS"
    if [ "$status" = PASS ]; then
        :
    else
        FAILURES=$((FAILURES + 1))
        printf 'FAIL %s: %s\n' "$id" "$detail" >&2
    fi
}

ids_from_source() {
    awk '/QA-TEST:/ { line=$0; sub(/^.*QA-TEST:[[:space:]]*/, "", line); sub(/[^A-Z0-9-].*$/, "", line); if (line != "") print line }' "$1"
}

record_source_group() {
    file=$1
    status=$2
    detail=$3
    ids_from_source "$file" > "$WORK/current.ids"
    while IFS= read -r id; do
        [ -n "$id" ] && record "$id" "$status" "$detail"
    done < "$WORK/current.ids"
}

run_executable_group() {
    category=$1
    src=$2
    expected_count=$3
    base=$(basename "$src" .CMOT)
    bin="$WORK/${category}-${base}"
    clog="$LOGS/${category}-${base}.compile.log"
    rlog="$LOGS/${category}-${base}.run.log"
    count=$(ids_from_source "$src" | wc -l | tr -d ' ')
    if [ "$count" -ne "$expected_count" ]; then
        record_source_group "$src" FAIL "fixture has $count IDs; expected $expected_count"
        return
    fi
    set +e
    "$CMOTIVE" "$src" -o "$bin" > "$clog" 2>&1
    crc=$?
    set +e
    if [ "$crc" -ne 0 ]; then
        record_source_group "$src" FAIL "compile failed; see ${clog#$ROOT/}"
        return
    fi
    set +e
    "$bin" > "$rlog" 2>&1
    rrc=$?
    set +e
    if [ "$rrc" -ne 0 ]; then
        record_source_group "$src" FAIL "runtime returned $rrc; see ${rlog#$ROOT/}"
        return
    fi
    record_source_group "$src" PASS "$category group $base compiled and executed"
    printf 'PASS %-18s %s (%s tests)\n' "$category" "$base" "$count"
}

if [ ! -x "$CMOTIVE" ] || [ ! -x "$CMOTIVEPP" ] || [ ! -x "$C2CMOTIVE" ]; then
    printf 'CMotive QA: build the tools first (missing executables under %s)\n' "$BIN_DIR" >&2
    exit 2
fi

printf 'CMotive QA: runtime language semantics\n'
for src in "$QA"/cases/runtime/*.CMOT; do
    run_executable_group language-runtime "$src" 32
done

printf 'CMotive QA: advanced language and standard-library features\n'
for src in "$QA"/cases/features/*.CMOT; do
    run_executable_group language-feature "$src" 4
done

printf 'CMotive QA: preprocessor exact-output and integrated compilation\n'
TAB=$(printf '\t')
exec 3< "$QA/cases/preprocessor/groups.tsv"
IFS="$TAB" read -r _header_a _header_b <&3 || true
while IFS="$TAB" read -r source defs <&3; do
    [ -n "$source" ] || continue
    src="$QA/cases/preprocessor/$source"
    base=${source%.CMOT}
    expanded="$WORK/$base.expanded.CMOT"
    expected="$QA/expected/preprocessor/$base.expected"
    bin="$WORK/$base.bin"
    plog="$LOGS/$base.preprocess.log"
    clog="$LOGS/$base.compile.log"
    rlog="$LOGS/$base.run.log"
    group_failures_before=$FAILURES
    set --
    if [ -n "${defs:-}" ]; then
        # Definitions are generated test data with no whitespace inside an option.
        # shellcheck disable=SC2086
        set -- $defs
    fi
    set +e
    "$CMOTIVEPP" -I "$QA/cases/preprocessor" -I "$QA/cases/preprocessor/plugins" "$@" "$src" -o "$expanded" > "$plog" 2>&1
    prc=$?
    set +e
    crc=1
    rrc=1
    if [ "$prc" -eq 0 ]; then
        set +e
        "$CMOTIVE" -I "$QA/cases/preprocessor" -I "$QA/cases/preprocessor/plugins" "$@" "$src" -o "$bin" > "$clog" 2>&1
        crc=$?
        if [ "$crc" -eq 0 ]; then
            "$bin" > "$rlog" 2>&1
            rrc=$?
        fi
        set +e
    fi
    while IFS="$TAB" read -r id expected_line; do
        [ -n "$id" ] || continue
        if [ "$prc" -ne 0 ]; then
            record "$id" FAIL "preprocessor failed for $source"
        elif ! grep -Fqx "$expected_line" "$expanded"; then
            record "$id" FAIL "expected expanded line missing in $base"
        elif [ "$crc" -ne 0 ]; then
            record "$id" FAIL "preprocessed source failed compilation for $base"
        elif [ "$rrc" -ne 0 ]; then
            record "$id" FAIL "preprocessed executable returned $rrc for $base"
        else
            record "$id" PASS "exact expansion and compiled behavior verified in $base"
        fi
    done < "$expected"
    expected_count=$(awk -F '\t' 'NF>=2{n++} END{print n+0}' "$expected")
    if [ "$expected_count" -ne 8 ]; then
        FAILURES=$((FAILURES + 1))
        printf 'FAIL preprocessor fixture %s has %s expected rows; expected 8\n' "$base" "$expected_count" >&2
    fi
    if [ "$FAILURES" -eq "$group_failures_before" ]; then
        printf 'PASS %-18s %s (8 tests)\n' preprocessor "$base"
    else
        printf 'FAIL %-18s %s\n' preprocessor "$base" >&2
    fi
done
exec 3<&-

printf 'CMotive QA: C-to-CMotive converter\n'
for csrc in "$QA"/cases/converter/*.c; do
    base=$(basename "$csrc" .c)
    cmot="$WORK/$base.CMOT"
    support="$WORK/${base}_support.h"
    native="$WORK/${base}-native"
    converted="$WORK/${base}-converted"
    native_out="$WORK/$base.native.out"
    converted_out="$WORK/$base.converted.out"
    expected="$QA/expected/converter/$base.expected"
    c2log="$LOGS/$base.converter.log"
    nlog="$LOGS/$base.native-compile.log"
    mlog="$LOGS/$base.cmotive-compile.log"
    group_failures_before=$FAILURES
    set +e
    "$CC_CMD" -std=c11 "$csrc" -o "$native" > "$nlog" 2>&1
    ncrc=$?
    nrrc=1
    if [ "$ncrc" -eq 0 ]; then "$native" > "$native_out" 2>&1; nrrc=$?; fi
    "$C2CMOTIVE" "$csrc" -o "$cmot" --support "$support" > "$c2log" 2>&1
    c2rc=$?
    mcrc=1
    mrrc=1
    if [ "$c2rc" -eq 0 ]; then
        "$CMOTIVE" -I "$WORK" "$cmot" -o "$converted" > "$mlog" 2>&1
        mcrc=$?
        if [ "$mcrc" -eq 0 ]; then "$converted" > "$converted_out" 2>&1; mrrc=$?; fi
    fi
    set +e
    ids_from_source "$csrc" > "$WORK/$base.ids"
    id_count=$(wc -l < "$WORK/$base.ids" | tr -d ' ')
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        if [ "$ncrc" -ne 0 ] || [ "$nrrc" -ne 0 ]; then
            record "$id" FAIL "native C reference failed for $base"
        elif [ "$c2rc" -ne 0 ]; then
            record "$id" FAIL "c2cmotive failed for $base"
        elif ! grep -Fq "$id" "$cmot" || ! grep -Fq "$id" "$support"; then
            record "$id" FAIL "converted function marker missing for $id"
        elif [ "$mcrc" -ne 0 ]; then
            record "$id" FAIL "converted CMotive failed compilation for $base"
        elif [ "$mrrc" -ne 0 ]; then
            record "$id" FAIL "converted executable returned $mrrc for $base"
        elif ! cmp -s "$native_out" "$converted_out"; then
            record "$id" FAIL "native and converted outputs differ for $base"
        elif ! cmp -s "$converted_out" "$expected"; then
            record "$id" FAIL "converted output differs from checked-in expectation for $base"
        else
            record "$id" PASS "function converted, compiled and behavior-matched in $base"
        fi
    done < "$WORK/$base.ids"
    if [ "$id_count" -ne 32 ]; then
        FAILURES=$((FAILURES + 1))
        printf 'FAIL converter fixture %s has %s IDs; expected 32\n' "$base" "$id_count" >&2
    fi
    if [ "$FAILURES" -eq "$group_failures_before" ]; then
        printf 'PASS %-18s %s (32 tests)\n' converter "$base"
    else
        printf 'FAIL %-18s %s\n' converter "$base" >&2
    fi
done

printf 'CMotive QA: expected failures and diagnostics\n'
exec 4< "$QA/cases/negative/cases.tsv"
IFS="$TAB" read -r _n1 _n2 _n3 _n4 <&4 || true
while IFS="$TAB" read -r id kind relpath expect <&4; do
    [ -n "$id" ] || continue
    path="$QA/$relpath"
    log="$LOGS/$id.log"
    out="$WORK/$id.out"
    set +e
    "$CMOTIVE" "$path" -o "$out" > "$log" 2>&1
    rc=$?
    set +e
    if [ "$rc" -eq 0 ]; then
        record "$id" FAIL "$kind unexpectedly succeeded"
    elif ! grep -Fq "$expect" "$log"; then
        record "$id" FAIL "$kind returned $rc without expected diagnostic: $expect"
    else
        record "$id" PASS "$kind returned nonzero status and expected diagnostic"
    fi
done
exec 4<&-

printf 'CMotive QA: compiler and tool command-line behavior\n'
set +e
sh "$QA/scripts/run_tool_tests.sh" "$BIN_DIR" "$EXEEXT" "$WORK/tool-results.tsv" "$WORK/tool-suite"
tool_rc=$?
set +e
cat "$WORK/tool-results.tsv" >> "$RESULTS"
if [ "$tool_rc" -ne 0 ]; then FAILURES=$((FAILURES + 1)); fi

# Structural result validation: every manifest ID exactly once, no extras.
tail -n +2 "$MANIFEST" | cut -f1 | sort > "$WORK/manifest.ids"
tail -n +2 "$RESULTS" | cut -f1 | sort > "$WORK/result.ids"
manifest_count=$(wc -l < "$WORK/manifest.ids" | tr -d ' ')
result_count=$(wc -l < "$WORK/result.ids" | tr -d ' ')
duplicate_count=$(uniq -d "$WORK/result.ids" | wc -l | tr -d ' ')
comm -23 "$WORK/manifest.ids" "$WORK/result.ids" > "$WORK/missing.ids"
comm -13 "$WORK/manifest.ids" "$WORK/result.ids" > "$WORK/unknown.ids"
missing_count=$(wc -l < "$WORK/missing.ids" | tr -d ' ')
unknown_count=$(wc -l < "$WORK/unknown.ids" | tr -d ' ')
failed_count=$(awk -F '\t' 'NR>1 && $2!="PASS"{n++} END{print n+0}' "$RESULTS")
passed_count=$(awk -F '\t' 'NR>1 && $2=="PASS"{n++} END{print n+0}' "$RESULTS")

if [ "$manifest_count" -lt 1000 ] || [ "$manifest_count" -ne 1200 ] || [ "$result_count" -ne "$manifest_count" ] || [ "$duplicate_count" -ne 0 ] || [ "$missing_count" -ne 0 ] || [ "$unknown_count" -ne 0 ] || [ "$failed_count" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
fi

END=$(date +%s 2>/dev/null || printf 0)
if [ "$START" -gt 0 ] 2>/dev/null && [ "$END" -ge "$START" ] 2>/dev/null; then DURATION=$((END - START)); else DURATION=0; fi

{
    printf '# CMotive Quality Assurance Results\n\n'
    printf '%s\n' "- **Manifest tests:** $manifest_count"
    printf '%s\n' "- **Reported results:** $result_count"
    printf '%s\n' "- **Passed:** $passed_count"
    printf '%s\n' "- **Failed:** $failed_count"
    printf '%s\n' "- **Duplicate result IDs:** $duplicate_count"
    printf '%s\n' "- **Missing result IDs:** $missing_count"
    printf '%s\n' "- **Unknown result IDs:** $unknown_count"
    printf '%s\n\n' "- **Elapsed seconds:** $DURATION"
    printf '## Category totals\n\n'
    printf '| Category | Total | Passed | Failed |\n'
    printf '|---|---:|---:|---:|\n'
    awk -F '\t' '
      FNR==NR && FNR>1 { status[$1]=$2; next }
      FNR>1 { total[$2]++; if(status[$1]=="PASS") pass[$2]++; else fail[$2]++ }
      END { for (c in total) printf "| %s | %d | %d | %d |\n", c,total[c],pass[c]+0,fail[c]+0 }
    ' "$RESULTS" "$MANIFEST" | sort
    printf '\n## Artifacts\n\n'
    printf '%s\n' '- Machine-readable results: `build/quality-assurance/results.tsv`'
    printf '%s\n' '- Per-group logs: `build/quality-assurance/logs/`'
    if [ "$failed_count" -eq 0 ] && [ "$missing_count" -eq 0 ] && [ "$unknown_count" -eq 0 ] && [ "$duplicate_count" -eq 0 ]; then
        printf '\n**Overall result: PASS**\n'
    else
        printf '\n**Overall result: FAIL**\n'
    fi
} > "$SUMMARY"

printf '\nCMotive QA summary: %s passed, %s failed, %s manifest tests\n' "$passed_count" "$failed_count" "$manifest_count"
printf 'Results: %s\n' "${RESULTS#$ROOT/}"
printf 'Summary: %s\n' "${SUMMARY#$ROOT/}"

if [ "$FAILURES" -ne 0 ]; then
    [ "$missing_count" -eq 0 ] || { printf 'Missing IDs:\n' >&2; cat "$WORK/missing.ids" >&2; }
    [ "$unknown_count" -eq 0 ] || { printf 'Unknown IDs:\n' >&2; cat "$WORK/unknown.ids" >&2; }
    exit 1
fi
exit 0
