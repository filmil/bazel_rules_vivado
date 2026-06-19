#!/usr/bin/env bash

# --- Begin Runfiles Setup ---
# https://github.com/bazelbuild/bazel/blob/master/tools/bash/runfiles/runfiles.bash
if [[ -z "${RUNFILES_DIR}" ]]; then
  if [[ -f "$0.runfiles_manifest" ]]; then
    export RUNFILES_DIR="$0.runfiles"
  fi
fi

if [[ -f "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${RUNFILES_DIR}/rules_vivado/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/rules_vivado/tools/bash/runfiles/runfiles.bash"
else
  echo "runfiles.bash not found"
  exit 1
fi
# --- End Runfiles Setup ---

source "$(rlocation fshlib/log.sh)"

_run_docker="$(rlocation rules_bid/build/docker_run)"
_gotopt2="$(rlocation rules_multitool~~multitool~multitool/tools/gotopt2/gotopt2)"
if [[ "${_gotopt2}" == "" ]]; then
    _gotopt2="$(rlocation rules_multitool++multitool+multitool/tools/gotopt2/gotopt2)"
    if [[ "${_gotopt2}" == "" ]]; then
        log::error "gotopt2 not found"
        exit 1
    fi
fi
_yaml_config="$(rlocation bazel_rules_vivado/build/vivado/bin/ilagen/flags.yaml)"
if [[ "${_yaml_config}" == "" ]]; then
    _yaml_config="$(rlocation rules_vivado/build/vivado/bin/ilagen/flags.yaml)"
fi

readonly _ltxfile="{{ .LtxFile }}"
if [[ ! -f "${_ltxfile}" && ! -L "${_ltxfile}" ]]; then
    echo "probes ltx file not found at ${_ltxfile}"
    exit 1
fi

GOTOPT2_OUTPUT=$(${_gotopt2} $@ <${_yaml_config})
if [[ "$?" == "11" ]]; then
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

readonly _tcl_script_file="read_ila.tcl"
# The root of the Vivado installation in the container's filesystem.
readonly _vivado_version="{{ .VivadoVersion }}"
readonly _vivado_root="/opt/Xilinx/${_vivado_version}/Vivado"

log::debug "Creating TCL script: ${_tcl_script_file}"
log::debug "Using probes file:   ${_ltxfile}"
log::debug "Using PWD:            ${PWD}"

# We write the TCL script that Vivado executes inside Docker.
cat <<EOF > "${_tcl_script_file}" || log::error "Could not create the file: ${_tcl_script_file}"
open_hw_manager
puts "INFO: Connecting to hardware server ${gotopt2_hostport}"
if { [catch { connect_hw_server -url ${gotopt2_hostport} } err] } {
    puts "ERROR: Could not connect to hw_server: \$err"
    exit 1
}

current_hw_target [get_hw_targets ${gotopt2_device}]
open_hw_target
set dev [lindex [get_hw_devices] 0]
current_hw_device \$dev

puts "INFO: Loading probes file ${_ltxfile}"
set_property PROBES.FILE ${_ltxfile} \$dev
refresh_hw_device \$dev

set ila [get_hw_ilas -of_objects \$dev]
if { \$ila == "" } {
    puts "ERROR: No ILA debug cores found on device!"
    exit 1
}

# Apply trigger condition if specified
if { "${gotopt2_trigger}" != "" } {
    puts "INFO: Configuring trigger: ${gotopt2_trigger}"
    set_property TRIGGER_COMPARE_VALUE "${gotopt2_trigger}" [get_hw_probes -of_objects \$ila *]
}

puts "INFO: Arming ILA core \$ila"
arm_hw_ila \$ila
wait_on_hw_ila \$ila

puts "INFO: Uploading captured data and writing to VCD"
write_hw_ila_data -force -vcd ${gotopt2_vcd} [upload_hw_ila_data \$ila]

puts "INFO: Done capturing."
close_hw_target
EOF

env RUNFILES_DIR="$PWD/.." \
"${_run_docker}" \
    --container=xilinx-vivado:${_vivado_version} \
    --dir-reference=${PWD} \
    --source-dir=${PWD} \
    --mounts=/tmp/.X11-unix:/tmp/.X11-unix:ro,"${PWD}:/work:rw" \
    --freeargs=--net=host,-e,HOME=/work,-w,/work \
    --src-mount=/work \
    LD_LIBRARY_PATH="${_vivado_root}/lib/lnx64.o" \
    "${_vivado_root}/bin/setEnvAndRunCmd.sh" vivado \
    -notrace -mode batch \
    -source "/work/${_tcl_script_file}" | log::prefix "[vivado] " \
    && log::info "VCD file successfully created at ${PWD}/${gotopt2_vcd}" \
    || log::error "The ILA reading command failed."
