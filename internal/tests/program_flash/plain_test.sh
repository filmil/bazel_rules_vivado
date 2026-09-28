#!/usr/bin/env bash
# With no `loaddata`, the TCL is the one line it always was.
set -euo pipefail
tcl="$1"
cat "$tcl"
want='^write_cfgmem -force -format mcs -size 16 -interface SPIx4 -loadbit \{up 0x0 [^ ]*design.bit\} -file [^ ]*flash_plain.mcs$'
if ! grep -Eq -- "$want" "$tcl" || grep -q -- -loaddata "$tcl"; then
	echo "FAIL: expected exactly: $want" >&2
	exit 1
fi
echo "PASS"
