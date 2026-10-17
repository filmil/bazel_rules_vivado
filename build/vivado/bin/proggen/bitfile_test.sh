#!/usr/bin/env bash
# The bitstream that vivado_program_device's script programs: the target's
# own, or the one --bitfile names, checked against --sha256.
set -uo pipefail
source "$1"

failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
cd "${tmp}"

# A file that starts as a Xilinx .bit file does, and one that does not.
printf '\x00\x09\x0f\xf0\x0f\xf0\x0f\xf0\x0f\xf0\x00\x00\x01built' > built.bit
printf '\x00\x09\x0f\xf0\x0f\xf0\x0f\xf0\x0f\xf0\x00\x00\x01checked' > checked.bit
echo "write_bitstream failed" > placeholder.bit
checked_sha="$(sha256sum checked.bit)"
checked_sha="${checked_sha%% *}"

# expect NAME WANT [ARGS...]: proggen::bitfile ARGS prints exactly WANT.
function expect() {
	local name="$1" want="$2"
	shift 2
	local got
	if ! got="$(proggen::bitfile "$@" 2>&1)"; then
		echo "FAIL: ${name}: failed: ${got}"
		failures=$((failures + 1))
	elif [[ "${got}" != "${want}" ]]; then
		printf 'FAIL: %s\n--- want\n%s\n--- got\n%s\n' "${name}" "${want}" "${got}"
		failures=$((failures + 1))
	fi
}

# refuse NAME WHY [ARGS...]: proggen::bitfile ARGS fails, saying WHY.
function refuse() {
	local name="$1" why="$2"
	shift 2
	local got
	if got="$(proggen::bitfile "$@" 2>&1)"; then
		echo "FAIL: ${name}: accepted, printed ${got}"
		failures=$((failures + 1))
	elif [[ "${got}" != *"${why}"* ]]; then
		printf 'FAIL: %s: the error does not say "%s":\n%s\n' "${name}" "${why}" "${got}"
		failures=$((failures + 1))
	fi
}

expect "the target's own" "built.bit" built.bit "" "" copy.bit

expect "--bitfile, copied to where Vivado sees it" "copy.bit" built.bit "${tmp}/checked.bit" "" copy.bit
if ! cmp -s checked.bit copy.bit; then
	echo "FAIL: the copy is not the file --bitfile names"
	failures=$((failures + 1))
fi
rm -f copy.bit

mkdir run work
BUILD_WORKING_DIRECTORY="${tmp}" expect "a relative --bitfile, from where bazel run started" \
	"work/copy.bit" built.bit checked.bit "" work/copy.bit
pushd run >/dev/null
expect "a relative --bitfile, without bazel run" "copy.bit" "" ../checked.bit "" copy.bit
popd >/dev/null

expect "--bitfile with its SHA-256" "copy.bit" built.bit "${tmp}/checked.bit" "${checked_sha}" copy.bit
expect "a SHA-256 in upper case" "copy.bit" built.bit "${tmp}/checked.bit" "${checked_sha^^}" copy.bit
expect "the target's own, with its SHA-256" "built.bit" built.bit "" \
	"$(sha256sum built.bit | cut -d' ' -f1)" copy.bit
expect "no bitstream of its own, and --bitfile" "copy.bit" "" "${tmp}/checked.bit" "" copy.bit

refuse "no bitstream at all" "--bitfile is required" "" "" "" copy.bit
refuse "a --bitfile that is not there" "no such file" built.bit "${tmp}/missing.bit" "" copy.bit
refuse "a SHA-256 that differs" "--sha256" built.bit "${tmp}/checked.bit" \
	"0000000000000000000000000000000000000000000000000000000000000000" copy.bit
refuse "the target's own, with another's SHA-256" "--sha256" built.bit "" "${checked_sha}" copy.bit
refuse "a placeholder, not a bitstream" "not a bitstream" placeholder.bit "" "" copy.bit
refuse "a --bitfile that is a placeholder" "not a bitstream" built.bit "${tmp}/placeholder.bit" "" copy.bit
refuse "the target's own, missing" "not found" gone.bit "" "" copy.bit

# A --bitfile that a check refuses leaves no copy behind.
refuse "a SHA-256 that differs, again" "--sha256" built.bit "${tmp}/checked.bit" \
	"0000000000000000000000000000000000000000000000000000000000000000" copy.bit
if [[ -e copy.bit ]]; then
	echo "FAIL: the copy of a --bitfile with the wrong SHA-256 was left behind"
	failures=$((failures + 1))
fi
refuse "a placeholder, again" "not a bitstream" built.bit "${tmp}/placeholder.bit" "" copy.bit
if [[ -e copy.bit ]]; then
	echo "FAIL: the copy of a placeholder --bitfile was left behind"
	failures=$((failures + 1))
fi

# A --bitfile that is the copy itself is neither copied onto itself nor,
# when refused, removed.
cp checked.bit copy.bit
expect "a --bitfile that is the copy" "copy.bit" built.bit "${tmp}/copy.bit" "${checked_sha}" copy.bit
refuse "a --bitfile that is the copy, refused" "--sha256" built.bit "${tmp}/copy.bit" \
	"0000000000000000000000000000000000000000000000000000000000000000" copy.bit
if ! cmp -s checked.bit copy.bit; then
	echo "FAIL: a refused --bitfile that is the copy itself was changed or removed"
	failures=$((failures + 1))
fi
rm -f copy.bit

# The start of a file that is not a bitstream is shown so that a terminal
# shows it as text.
printf '\033[2Jbinary\001\002' > binary.bit
got="$(proggen::bitfile binary.bit "" "" copy.bit 2>&1)"
if [[ "${got}" == *$'\033'* ]]; then
	echo "FAIL: a control character of a non-bitstream reached the terminal"
	failures=$((failures + 1))
fi

if [[ "${failures}" -gt 0 ]]; then
	echo "${failures} failed"
	exit 1
fi
echo "PASS"
