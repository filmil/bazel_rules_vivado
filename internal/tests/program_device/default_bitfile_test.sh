#!/usr/bin/env bash
# The bitstream that each program script falls back on when --bitfile is
# not given: the one its deps built, or none.
set -euo pipefail
with_deps="$1"
without_deps="$2"

failures=0

# has FILE PATTERN WHAT: FILE has a line matching PATTERN, an extended
# regular expression.
function has() {
	if ! grep -Eq -- "$2" "$1"; then
		echo "FAIL: $3: no line matches: $2"
		failures=$((failures + 1))
	fi
}

has "${with_deps}" 'proggen::bitfile "internal/tests/program_device/design\.bit" "\$\{gotopt2_bitfile\}" "\$\{gotopt2_sha256\}"' \
	"a target with deps programs its own bitstream by default"
has "${without_deps}" 'proggen::bitfile "" "\$\{gotopt2_bitfile\}" "\$\{gotopt2_sha256\}"' \
	"a target without deps has no bitstream of its own"
for script in "${with_deps}" "${without_deps}"; do
	has "${script}" 'build/vivado/bin/proggen/bitfile\.bash' "the script sources bitfile.bash"
done

if [[ "${failures}" -gt 0 ]]; then
	exit 1
fi
echo "PASS"
