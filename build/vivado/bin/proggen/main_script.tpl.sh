#! /bin/bash
# GENERATED FILE DO NOT EDIT
#
# Generated as:  {{ .Outfile }}
# From template: {{ .TemplateFile }}
#
set -eo pipefail

# --- begin runfiles.bash initialization ---
# Copy-pasted from Bazel's Bash runfiles library (tools/bash/runfiles/runfiles.bash).
if [[ ! -d "${RUNFILES_DIR:-/dev/null}" && ! -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  if [[ -f "$0.runfiles_manifest" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
  elif [[ -f "$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
  elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
    export RUNFILES_DIR="$0.runfiles"
  fi
fi
if [[ -f "${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \
            "$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

_log_bash_loc="$(rlocation fshlib~/log.bash)"
if [[ "${_log_bash_loc}" == "" ]]; then
    _log_bash_loc="$(rlocation fshlib+/log.bash)"
    if [[ "${_log_bash_loc}" == "" ]]; then
        echo >2 "ERROR: could not find:fshlib/log.bash"
        exit 1
    fi
fi
source "${_log_bash_loc}"

readonly _this_dir="${0%/*}"
log::debug "this_dir: ${_this_dir}"

# The runner script comes from the Vivado toolchain: docker_run in docker
# mode, host_run in host mode.
_run_docker=""
if [[ "{{ .RunnerRlocation }}" != "" ]]; then
    _run_docker="$(rlocation "{{ .RunnerRlocation }}")"
fi
# These fallbacks should be immune to path changes.
if [[ "${_run_docker}" == "" ]]; then
    _run_docker="$(rlocation rules_bid+/build/docker_run.sh)"
fi
if [[ "${_run_docker}" == "" ]]; then
    _run_docker="$(rlocation rules_bid+/build/docker_run_/docker_run)"
fi
readonly _run_docker

_gotopt2="$(rlocation rules_multitool~~multitool~multitool/tools/gotopt2/gotopt2)"
if [[ "${_gotopt2}" == "" ]]; then
    # Try for the new repo names.
    _gotopt2="$(rlocation rules_multitool++multitool+multitool/tools/gotopt2/gotopt2)"
    if [[ "${_gotopt2}" == "" ]]; then
        eilo::error "gotopt2 not found"
        exit 1
    fi
fi
_yaml_config="$(rlocation bazel_rules_vivado/build/vivado/bin/proggen/flags.yaml)"
if [[ "${_yaml_config}" == "" ]]; then
    _yaml_config="$(rlocation rules_vivado/build/vivado/bin/proggen/flags.yaml)"
fi

readonly _bitfile="{{ .BitFile }}"
if [[ ! -f "${_bitfile}" && ! -L "${_bitfile}" ]]; then
    echo "bit file not found at ${_bitfile}"
    ls -lR
    exit 1
fi

GOTOPT2_OUTPUT=$(${_gotopt2} $@ <${_yaml_config})
if [[ "$?" == "11" ]]; then
  # When --help option is used, gotopt2 exits with code 11.
  exit 1
fi

eval "${GOTOPT2_OUTPUT}"

if [[ "${gotopt2_hostport}" == "" ]]; then
    echo "--hostport is required, often the value should be 'localhost:3122'"
    exit 1
fi

if [[ "${gotopt2_device}" == "" ]]; then
    echo "--device is required"
    exit 1
fi

readonly _tcl_script_file="prog.tcl"
# The root of the Vivado installation (in the container's filesystem in
# docker mode, on the host filesystem in host mode).
readonly _vivado_version="{{ .VivadoVersion }}"
readonly _vivado_root="{{ .VivadoPath }}"
# Where generated files are visible to Vivado: /work in the container,
# the current directory on the host.
readonly _work_dir="{{ .WorkDir }}"

log::debug "Creating script file: ${_tcl_script_file}"
log::debug "Using bitfile:        ${_bitfile}"
log::debug "Using PWD:            ${PWD}"

# Now, run the daemon.
readonly _prog_runner_binary="{{ .ProgRunnerBinary }}"
if [[ "${_prog_runner_binary}" != "" ]]; then
    if [[ ! -x "${_prog_runner_binary}" ]]; then
        log::error "programmer runner binary specified, but does not exist: "${_prog_runner_binary}
        exit 1
    fi
    readonly _prog_runner_args="{{ .ProgRunnerArgs }}"
    # The args must be without quotes so that the spaces are expanded.
    log::debug "Running programmer binary: ${_prog_runner_binary} ${_prog_runner_args}"
    "${_prog_runner_binary}" ${_prog_runner_args} &
    # The daemon may have a hardware server to start and a tunnel to
    # stand before that server answers, which takes longer than Vivado
    # takes to reach `connect_hw_server`; a server that had timed out
    # is what a first run on a cold machine meets, and it failed there
    # while working everywhere a server was already up. So the run
    # waits here until the server speaks. A connection alone is not
    # enough: a tunnel's local end accepts one whether or not the far
    # end is there. A TCF server sends its hello on connection, so the
    # wait asks for one byte, up to two minutes, and says which port it
    # waited on if none ever comes (HDL/txhdl#392).
    _wait_host="${gotopt2_hostport%:*}"
    _wait_port="${gotopt2_hostport##*:}"
    _waited=0
    until timeout 6 bash -c \
        'exec 3<>"/dev/tcp/$1/$2" && read -t 4 -n 1 _c <&3' _ \
        "${_wait_host}" "${_wait_port}" 2>/dev/null; do
        if [[ "${_waited}" -ge 120 ]]; then
            log::error "the hardware server at ${gotopt2_hostport} did not answer in ${_waited} s"
            exit 1
        fi
        sleep 1
        _waited=$((_waited + 1))
    done
    log::debug "the hardware server at ${gotopt2_hostport} answers, after ${_waited} s"
else
    log::warn "No programmer binary, skipping"
fi

cat <<EOF > "${_tcl_script_file}" || log::error "Could not create the file: ${_tcl_script_file}"
# Vivado tcl script here.
#
# https://stackoverflow.com/questions/50060337/programming-device-in-vivado-using-tcl
puts "INFO: Opening hardware manager"
open_hw_manager

puts "INFO: Connecting to the programming cable on ${gotopt2_hostport}"
connect_hw_server -url ${gotopt2_hostport}
current_hw_target [get_hw_targets $gotopt2_device]
open_hw_target
puts "INFO: Done connecting."

set Device [lindex [get_hw_devices] 0]
current_hw_device \$Device
refresh_hw_device -update_hw_probes false \$Device

set_property PROGRAM.FILE $_bitfile \$Device

#set_property PROBES.FILE "C:/design.ltx" \$Device

puts "INFO: Programming device with bitstream: $_bitfile"
program_hw_devices \$Device
puts "INFO: DONE Programming device."

puts "INFO: Refresh."
refresh_hw_device \$Device
puts "INFO: Done."
EOF

env RUNFILES_DIR="$PWD/.." \
"${_run_docker}" \
    --container={{ .Container }} \
    --dir-reference=${PWD} \
    --source-dir=${PWD} \
    --mounts=/tmp/.X11-unix:/tmp/.X11-unix:ro,"${PWD}:/work:rw" \
    --freeargs=--net=host,-e,HOME=/work,-w,/work \
    --src-mount=/work \
    LD_LIBRARY_PATH="${_vivado_root}/lib/lnx64.o" \
    "${_vivado_root}/bin/setEnvAndRunCmd.sh" vivado \
    -notrace -mode batch \
    -source "${_work_dir}/${_tcl_script_file}" | log::prefix "[vivado] " \
    && log::info "OK" \
    || log::error "The programming command failed."

