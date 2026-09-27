#!/bin/bash
# failure_report.sh on a log longer than it prints: it exits 1, writes
# nothing to standard output, and writes the errors and the log's end
# to standard error, but not the middle of the log.
set -u
report="$1"
dir="${TEST_TMPDIR:-$(mktemp -d)}"
log="${dir}/run.log"
{
  echo "ERROR: [Place 30-1] an early error"
  for i in $(seq 1 5000); do echo "INFO: line ${i}"; done
  echo "CRITICAL WARNING: [Vivado 12-4739] a late critical warning"
  echo "timing is not met: the worst setup slack is -5.725 ns"
} > "${log}"
out="${dir}/out"
err="${dir}/err"
"${report}" "${log}" > "${out}" 2> "${err}"
code=$?
fail() { echo "FAIL: $*"; cat "${err}"; exit 1; }
[ "${code}" -eq 1 ] || fail "exit ${code}, expected 1"
[ ! -s "${out}" ] || fail "wrote to standard output"
grep -q "an early error" "${err}" || fail "no early ERROR line"
grep -q "a late critical warning" "${err}" || fail "no CRITICAL WARNING line"
grep -q "timing is not met" "${err}" || fail "no last line"
grep -q "INFO: line 2500$" "${err}" && fail "printed the middle of the log"
[ "$(wc -l < "${err}")" -lt 200 ] || fail "more than 200 lines"
echo PASS
