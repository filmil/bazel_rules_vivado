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

_log_bash_loc="$(rlocation fshlib~/log.bash)"
if [[ "${_log_bash_loc}" == "" ]]; then
    _log_bash_loc="$(rlocation fshlib+/log.bash)"
    if [[ "${_log_bash_loc}" == "" ]]; then
        echo >2 "ERROR: could not find:fshlib/log.bash"
        exit 1
    fi
fi
source "${_log_bash_loc}"

# The runner script comes from the Vivado toolchain: docker_run in docker
# mode, host_run in host mode.
_run_docker=""
if [[ "{{ .RunnerRlocation }}" != "" ]]; then
    _run_docker="$(rlocation "{{ .RunnerRlocation }}")"
fi
if [[ "${_run_docker}" == "" ]]; then
    _run_docker="$(rlocation rules_bid/build/docker_run)"
fi
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
_triggers_lib="$(rlocation bazel_rules_vivado/build/vivado/bin/ilagen/triggers.bash)"
if [[ "${_triggers_lib}" == "" ]]; then
    _triggers_lib="$(rlocation rules_vivado/build/vivado/bin/ilagen/triggers.bash)"
fi
if [[ "${_triggers_lib}" == "" ]]; then
    log::error "triggers.bash not found"
    exit 1
fi
source "${_triggers_lib}"

readonly _ltxfile="{{ .LtxFile }}"
if [[ ! -f "${_ltxfile}" && ! -L "${_ltxfile}" ]]; then
    echo "probes ltx file not found at ${_ltxfile}"
    exit 1
fi

GOTOPT2_OUTPUT=$("${_gotopt2}" "$@" <"${_yaml_config}")
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

# A relative --trigger_file is relative to where `bazel run` was started,
# not to the runfiles directory the script runs in.
_trigger_file="${gotopt2_trigger_file}"
if [[ "${_trigger_file}" != "" && "${_trigger_file}" != /* ]]; then
    _trigger_file="${BUILD_WORKING_DIRECTORY:-${PWD}}/${_trigger_file}"
fi
_trigger_tcl="$(ilagen::trigger_tcl "${_trigger_file}" "${gotopt2_trigger__list[@]}")" || exit 1

for _flag in trigger_position window_count; do
    _value="gotopt2_${_flag}"
    if [[ "${!_value}" != "" && ! "${!_value}" =~ ^[0-9]+$ ]]; then
        echo "--${_flag} must be a whole number, got: ${!_value}"
        exit 1
    fi
done
# The window count comes first: it bounds the trigger position.
_control_tcl=""
if [[ "${gotopt2_window_count}" != "" ]]; then
    _control_tcl+="set_property CONTROL.WINDOW_COUNT ${gotopt2_window_count} \$ila"$'\n'
fi
if [[ "${gotopt2_trigger_position}" != "" ]]; then
    _control_tcl+="set_property CONTROL.TRIGGER_POSITION ${gotopt2_trigger_position} \$ila"$'\n'
fi

readonly _tcl_script_file="read_ila.tcl"
# The root of the Vivado installation (in the container's filesystem in
# docker mode, on the host filesystem in host mode).
readonly _vivado_version="{{ .VivadoVersion }}"
readonly _vivado_root="{{ .VivadoPath }}"
# Where generated files are visible to Vivado: /work in the container,
# the current directory on the host.
readonly _work_dir="{{ .WorkDir }}"

log::debug "Creating TCL script: ${_tcl_script_file}"
log::debug "Using probes file:   ${_ltxfile}"
log::debug "Using PWD:            ${PWD}"

# We write the TCL script that Vivado executes. The procs come first, in a
# quoted heredoc so that their TCL needs no shell escapes.
cat <<'EOF' > "${_tcl_script_file}" || { log::error "Could not create the file: ${_tcl_script_file}"; exit 1; }
# The probe of the core whose NAME is name. A trailing bus range such as
# [34:0] may be given or left out.
proc ila_probe {ila name} {
    set probes [get_hw_probes -of_objects $ila]
    set bare [regsub {\[[0-9]+:[0-9]+\]$} $name {}]
    foreach p $probes {
        set n [get_property NAME $p]
        if {$n eq $name || [regsub {\[[0-9]+:[0-9]+\]$} $n {}] eq $bare} {
            return $p
        }
    }
    puts "ERROR: No probe named $name. The probes of the core are:"
    foreach p $probes {
        puts "    [get_property NAME $p] ([get_property WIDTH $p] bits)"
    }
    exit 1
}

proc ila_trigger {ila name value} {
    set p [ila_probe $ila $name]
    puts "INFO: Trigger: $name $value"
    set_property TRIGGER_COMPARE_VALUE $value $p
}

proc ila_trigger_all {ila value} {
    puts "INFO: Trigger on every probe: $value"
    set_property TRIGGER_COMPARE_VALUE $value [get_hw_probes -of_objects $ila]
}
EOF

cat <<EOF >> "${_tcl_script_file}" || { log::error "Could not write the file: ${_tcl_script_file}"; exit 1; }
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

${_control_tcl}
# Trigger conditions. Probes not named compare as don't-care.
${_trigger_tcl}

puts "INFO: Running ILA core \$ila"
run_hw_ila \$ila
wait_on_hw_ila \$ila

puts "INFO: Uploading captured data and writing to VCD"
write_hw_ila_data -force -vcd ${gotopt2_vcd} [upload_hw_ila_data \$ila]

puts "INFO: Done capturing."
close_hw_target
EOF

# The status of the pipeline below is Vivado's, not log::prefix's, and a
# failure exits non-zero rather than only saying so.
set -o pipefail
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
    && log::info "VCD file successfully created at ${PWD}/${gotopt2_vcd}" \
    || { log::error "The ILA reading command failed."; exit 1; }
