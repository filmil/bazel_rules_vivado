#!/usr/bin/env bash
# The flash image's TCL puts the bitstream at zero and the program at
# the address `loaddata` keys it to, in the one `write_cfgmem` call.
set -euo pipefail
tcl="$1"
cat "$tcl"
want='-loadbit {up 0x0 [^ ]*design.bit} -loaddata {up 0x00A00000 [^ ]*program.bin} -file'
if ! grep -Eq -- "$want" "$tcl"; then
	echo "FAIL: expected a match for: $want" >&2
	exit 1
fi
echo "PASS"
