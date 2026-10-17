# The bitstream that vivado_program_device programs.
#
# The generated program script sources this file. The target's own
# bitstream, the one its deps built, is programmed unless --bitfile names
# another, such as one that another session built and checked. --sha256
# makes sure that the file is that one.

# Every Xilinx .bit file starts with these 13 bytes. A placeholder that
# vivado_place_and_route2 wrote for a failed write_bitstream does not.
readonly _proggen_bit_header="00090ff00ff00ff00ff0000001"

# proggen::bitfile chooses the bitstream to program, checks it, and prints
# its path. A copy that it made of a --bitfile that fails a check is
# removed.
#
# Usage: proggen::bitfile BUILT FLAG SHA256 COPY
#
# BUILT is the target's own bitstream, or empty when it has none. FLAG is
# the --bitfile value. When it is not empty, that file is copied to COPY,
# a path in the directory that Vivado sees, and COPY is printed: in docker
# mode, Vivado sees no other directory of the host. A relative FLAG is
# relative to where `bazel run` was started. SHA256, when not empty, is
# the SHA-256, in hex, that the file must have.
function proggen::bitfile() {
	local _built="$1" _flag="$2" _sha256="$3" _copy="$4"
	local _bitfile="${_built}"
	if [[ "${_flag}" != "" ]]; then
		if [[ "${_flag}" != /* ]]; then
			_flag="${BUILD_WORKING_DIRECTORY:-${PWD}}/${_flag}"
		fi
		if [[ ! -f "${_flag}" ]]; then
			echo "ERROR: --bitfile: no such file: ${_flag}" >&2
			return 1
		fi
		if [[ ! "${_flag}" -ef "${_copy}" ]]; then
			if ! cp -f "${_flag}" "${_copy}"; then
				echo "ERROR: --bitfile: could not copy ${_flag} to ${_copy}" >&2
				rm -f "${_copy}"
				return 1
			fi
		fi
		_bitfile="${_copy}"
	fi
	if ! proggen::_check "${_bitfile}" "${_sha256}"; then
		if [[ "${_flag}" != "" && ! "${_flag}" -ef "${_copy}" ]]; then
			rm -f "${_copy}"
		fi
		return 1
	fi
	echo "${_bitfile}"
}

# proggen::_check checks that the bitstream $1 is there, has the SHA-256
# $2 when $2 is not empty, and starts as a Xilinx .bit file does.
function proggen::_check() {
	local _bitfile="$1" _sha256="$2"
	if [[ "${_bitfile}" == "" ]]; then
		echo "ERROR: this target has no bitstream of its own, so --bitfile is required" >&2
		return 1
	fi
	if [[ ! -f "${_bitfile}" && ! -L "${_bitfile}" ]]; then
		echo "ERROR: bit file not found at ${_bitfile}" >&2
		ls -lR >&2
		return 1
	fi
	if [[ "${_sha256}" != "" ]]; then
		local _want="${_sha256,,}" _got
		_got="$(sha256sum "${_bitfile}")" || return 1
		_got="${_got%% *}"
		if [[ "${_got}" != "${_want}" ]]; then
			echo "ERROR: --sha256: ${_bitfile} has SHA-256 ${_got}, not ${_want}" >&2
			return 1
		fi
	fi
	if [[ "$(head -c 13 "${_bitfile}" | od -An -tx1 | tr -d ' \n')" != "${_proggen_bit_header}" ]]; then
		echo "ERROR: not a bitstream: ${_bitfile}. It starts:" >&2
		head -c 200 "${_bitfile}" | cat -v >&2
		echo >&2
		return 1
	fi
}
