#! /bin/bash
# GENERATED FILE DO NOT EDIT
#
# Generated as:  {{ .Outfile }}
# From template: {{ .TemplateFile }}
#
set -eo pipefail

readonly _this_dir="${0%/*}"
echo this_dir: ${_this_dir}

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


# These should be immune to path changes.
readonly _run_docker="$(rlocation bazel_rules_bid/build/docker_run.sh)"

_gotopt2="$(rlocation rules_multitool~~multitool~multitool/tools/gotopt2/gotopt2)"
if [[ "${_gotopt2}" == "" ]]; then
    # Try for the new repo names.
    _gotopt2="$(rlocation rules_multitool++multitool+multitool/tools/gotopt2/gotopt2)"
    if [[ "${_gotopt2}" == "" ]]; then
        echo "gotopt2 not found"
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
# The root of the Vivado installation in the container's filesystem.
readonly _vivado_version="2025.1"
readonly _vivado_root="/opt/Xilinx/${_vivado_version}/Vivado"

echo "Creating script file: ${_tcl_script_file}"
echo "Using bitfile:        ${_bitfile}"
echo "Requested bitfile:    {{ .BitFile }}"

# Now, run the daemon.
readonly _prog_runner_binary="{{ .ProgRunnerBinary }}"
if [[ "${_prog_runner_binary}" != "" ]]; then
    if [[ ! -x "${_prog_runner_binary}" ]]; then
        echo "runner binary specified but does not exist"
        exit 1
    fi
    readonly _prog_runner_args="{{ .ProgRunnerArgs }}"
    # The args must be without quotes so that the spaces are expanded.
    echo "Running programmer binary: ${_prog_runner_binary} ${_prog_runner_args}"
    "${_prog_runner_binary}" ${_prog_runner_args} &
else
    echo "No programmer binary, skipping"
fi

cat <<EOF > "${_tcl_script_file}"
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
    --container=xilinx-vivado:${_vivado_version} \
    --dir-reference=${PWD} \
    --source-dir=${PWD} \
    --mounts=/tmp/.X11-unix:/tmp/.X11-unix:ro \
    --freeargs=--net=host,-e,HOME=/work,-w,/work \
    --src-mount=/work \
    LD_LIBRARY_PATH="${_vivado_root}/lib/lnx64.o" \
    "${_vivado_root}/bin/setEnvAndRunCmd.sh" vivado \
    -notrace -mode batch \
    -source "/work/${_tcl_script_file}"

