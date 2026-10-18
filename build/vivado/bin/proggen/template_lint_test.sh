#!/usr/bin/env bash
# Checks the launcher templates for two mistakes that made a launcher exit
# silently.
#
# 1. Under `set -e`, `x="$(rlocation a)"` ends the script when rlocation
#    fails, before the fallback path on the next line is tried. rlocation
#    fails when the runfiles come from a directory (a sh_test with the
#    launcher in its data) and the first name is absent; under `bazel run`
#    (a manifest) it prints nothing and succeeds, so the bug only shows in
#    tests. Each such assignment needs `|| true`.
# 2. `echo >2 ...` writes to a file named 2. It needs `>&2`.
#
# Usage: template_lint_test.sh <template>...
set -uo pipefail

failed=0
for template in "$@"; do
  if bad="$(grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*="?\$\(rlocation [^)]*\)"?[[:space:]]*$' "${template}")"; then
    echo "FAIL: ${template}: rlocation assignment without '|| true':" >&2
    echo "${bad}" >&2
    failed=1
  fi
  if bad="$(grep -nE '(^|[[:space:]])>2([[:space:]]|$)' "${template}")"; then
    echo "FAIL: ${template}: '>2' writes to a file named 2; use '>&2':" >&2
    echo "${bad}" >&2
    failed=1
  fi
done
if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi
echo "PASS: $# template(s)"
