#!/usr/bin/env bash
# The TCL that vivado_read_ila's trigger flags turn into.
set -uo pipefail
source "$1"

failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# expect NAME WANT [ARGS...]: ilagen::trigger_tcl ARGS prints exactly WANT.
function expect() {
	local name="$1" want="$2"
	shift 2
	local got
	if ! got="$(ilagen::trigger_tcl "$@" 2>&1)"; then
		echo "FAIL: ${name}: failed: ${got}"
		failures=$((failures + 1))
	elif [[ "${got}" != "${want}" ]]; then
		printf 'FAIL: %s\n--- want\n%s\n--- got\n%s\n' "${name}" "${want}" "${got}"
		failures=$((failures + 1))
	fi
}

# refuse NAME [ARGS...]: ilagen::trigger_tcl ARGS fails.
function refuse() {
	local name="$1"
	shift
	if ilagen::trigger_tcl "$@" >/dev/null 2>&1; then
		echo "FAIL: ${name}: accepted"
		failures=$((failures + 1))
	fi
}

expect "no triggers" "" ""

# Before the change a bare value was the only form. It still applies to
# every probe.
expect "bare value" 'ila_trigger_all $ila {eq1'"'"'b1}' "" "eq1'b1"

expect "one probe" 'ila_trigger $ila {state} {eq3'"'"'h5}' "" "state=eq3'h5"

expect "two probes, bus range kept" \
	'ila_trigger $ila {valid} {eq1'"'"'b1}
ila_trigger $ila {addr[34:0]} {eq35'"'"'h0_0000_0040}' \
	"" "valid=eq1'b1" "addr[34:0]=eq35'h0_0000_0040"

cat >"${tmp}/triggers" <<'TRIGGERS'
# The write strobe, and the address it writes.

valid  eq1'b1
	addr   eq35'h0_0000_0040
TRIGGERS
expect "file, then flags" \
	'ila_trigger $ila {valid} {eq1'"'"'b1}
ila_trigger $ila {addr} {eq35'"'"'h0_0000_0040}
ila_trigger $ila {state} {neq3'"'"'h0}' \
	"${tmp}/triggers" "state=neq3'h0"

printf 'valid eq1'"'"'b1' >"${tmp}/no_newline"
expect "file without a final newline" 'ila_trigger $ila {valid} {eq1'"'"'b1}' \
	"${tmp}/no_newline"

refuse "missing file" "${tmp}/absent"
printf 'valid\n' >"${tmp}/one_word"
refuse "file line with no value" "${tmp}/one_word"
printf 'valid eq1 b1\n' >"${tmp}/three_words"
refuse "file line with three words" "${tmp}/three_words"
refuse "empty value" "" "state="
refuse "empty probe" "" "=eq1'b1"
refuse "brace in a value" "" "state=eq3'h5}"
refuse "backslash in a name" "" 'st\ate=eq1'"'"'b1'
refuse "space in a value" "" "state=eq 1"

if [[ "${failures}" != 0 ]]; then
	echo "${failures} failed"
	exit 1
fi
echo "PASS"
