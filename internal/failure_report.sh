#!/bin/bash
# What a failed Vivado run says on the console, from its log.
#
# A long Vivado run writes megabytes of log. The rules used to `cat`
# the whole of it onto the action's standard output when the run
# failed, and Bazel prints nothing of an output over its limit, one
# megabyte by default, so a failed place and route said only that it
# had failed. This writes the part that says why: every `ERROR` and
# `CRITICAL WARNING` line, the last fifty of them, then the last lines
# of the log, where a Tcl error and Vivado's own exit are. All of it
# goes to standard error, and it exits 1, since it runs only when the
# run has failed.
#
# Usage: failure_report.sh <log>
set -u
log="$1"
lines="${FAILURE_REPORT_TAIL:-100}"
{
  echo "Vivado failed. Its errors and critical warnings, the last 50:"
  grep -E '^(ERROR|CRITICAL WARNING)' "${log}" | tail -n 50
  echo "The last ${lines} lines of its log:"
  tail -n "${lines}" "${log}"
} >&2
exit 1
