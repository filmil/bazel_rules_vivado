# Trigger conditions for vivado_read_ila, turned into TCL.
#
# The generated read script sources this file. A trigger names one probe
# and the value that probe compares against; probes not named stay at
# their default, which is "don't care".
#
# The output is one TCL command per trigger, for procs that the read
# script defines:
#
#   ila_trigger $ila {probe} {value}   one probe
#   ila_trigger_all $ila {value}       every probe (a bare --trigger value)
#
# Names and values go inside TCL braces, so a name or value that holds a
# brace, a backslash or whitespace is refused rather than quoted.

# ilagen::_trigger_word checks that $2 can stand inside TCL braces. $1 is
# where it came from, for the error message.
function ilagen::_trigger_word() {
	local _where="$1"
	local _word="$2"
	if [[ "${_word}" == "" ]]; then
		echo "ERROR: ${_where}: empty probe name or value" >&2
		return 1
	fi
	if [[ "${_word}" =~ [[:space:]\{\}\\] ]]; then
		echo "ERROR: ${_where}: '${_word}' holds whitespace, a brace or a backslash" >&2
		return 1
	fi
}

# ilagen::trigger_tcl prints the TCL for the triggers given.
#
# Usage: ilagen::trigger_tcl TRIGGER_FILE [TRIGGER...]
#
# TRIGGER_FILE may be empty. Each of its lines is "probe value"; blank
# lines and lines starting with "#" are skipped. Each TRIGGER is
# "probe=value", or a bare value that applies to every probe.
function ilagen::trigger_tcl() {
	local _file="$1"
	shift
	local _lineno=0
	local _line _probe _value _rest
	if [[ "${_file}" != "" ]]; then
		if [[ ! -r "${_file}" ]]; then
			echo "ERROR: --trigger_file: cannot read ${_file}" >&2
			return 1
		fi
		while IFS= read -r _line || [[ "${_line}" != "" ]]; do
			_lineno=$((_lineno + 1))
			if [[ "${_line}" =~ ^[[:space:]]*(#|$) ]]; then
				continue
			fi
			read -r _probe _value _rest <<<"${_line}"
			if [[ "${_value}" == "" || "${_rest}" != "" ]]; then
				echo "ERROR: ${_file}:${_lineno}: want 'probe value', got: ${_line}" >&2
				return 1
			fi
			ilagen::_trigger_word "${_file}:${_lineno}" "${_probe}" || return 1
			ilagen::_trigger_word "${_file}:${_lineno}" "${_value}" || return 1
			echo "ila_trigger \$ila {${_probe}} {${_value}}"
		done <"${_file}"
	fi
	local _trigger
	for _trigger in "$@"; do
		if [[ "${_trigger}" == *=* ]]; then
			_probe="${_trigger%%=*}"
			_value="${_trigger#*=}"
			ilagen::_trigger_word "--trigger=${_trigger}" "${_probe}" || return 1
			ilagen::_trigger_word "--trigger=${_trigger}" "${_value}" || return 1
			echo "ila_trigger \$ila {${_probe}} {${_value}}"
		else
			ilagen::_trigger_word "--trigger=${_trigger}" "${_trigger}" || return 1
			echo "ila_trigger_all \$ila {${_trigger}}"
		fi
	done
}
