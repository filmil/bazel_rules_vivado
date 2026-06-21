#! /bin/bash
# GENERATED FILE DO NOT EDIT
#
# Generated as:  {{ .Outfile }}
# From template: {{ .TemplateFile }}
#
# Programs the device's NON-VOLATILE configuration flash (SPI/QSPI) so the
# design loads automatically on power-up. Unlike volatile JTAG programming,
# this persists across power cycles.
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

# These should be immune to path changes.
_run_docker="$(rlocation rules_bid+/build/docker_run.sh)"
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

readonly _mcsfile="{{ .McsFile }}"
if [[ ! -f "${_mcsfile}" && ! -L "${_mcsfile}" ]]; then
    echo "flash image (.mcs) not found at ${_mcsfile}"
    ls -lR
    exit 1
fi

readonly _flash_part="{{ .FlashPart }}"
if [[ "${_flash_part}" == "" ]]; then
    echo "no flash part configured (rule attribute 'flash_part' is required)"
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

readonly _tcl_script_file="prog_flash.tcl"
# The root of the Vivado installation in the container's filesystem.
readonly _vivado_version="{{ .VivadoVersion }}"
readonly _vivado_root="/opt/Xilinx/${_vivado_version}/Vivado"

log::debug "Creating script file: ${_tcl_script_file}"
log::debug "Using flash image:    ${_mcsfile}"
log::debug "Using flash part:     ${_flash_part}"
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
else
    log::warn "No programmer binary, skipping"
fi

cat <<EOF > "${_tcl_script_file}" || log::error "Could not create the file: ${_tcl_script_file}"
# Vivado tcl script: program the device's configuration flash (cfgmem).
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

puts "INFO: Creating configuration memory for flash part: $_flash_part"
create_hw_cfgmem -hw_device \$Device [lindex [get_cfgmem_parts {$_flash_part}] 0]
set Cfgmem [get_property PROGRAM.HW_CFGMEM \$Device]

set_property PROGRAM.FILES [list "$_mcsfile"] \$Cfgmem
set_property PROGRAM.ADDRESS_RANGE {use_file} \$Cfgmem
set_property PROGRAM.BLANK_CHECK 0 \$Cfgmem
set_property PROGRAM.ERASE 1 \$Cfgmem
set_property PROGRAM.CFG_PROGRAM 1 \$Cfgmem
set_property PROGRAM.VERIFY 1 \$Cfgmem
set_property PROGRAM.CHECKSUM 0 \$Cfgmem

puts "INFO: Loading configuration-memory programming bridge into the FPGA"
create_hw_bitstream -hw_device \$Device [get_property PROGRAM.HW_CFGMEM_BITFILE \$Device]
program_hw_devices \$Device
refresh_hw_device \$Device

puts "INFO: Programming configuration flash with: $_mcsfile"
program_hw_cfgmem -hw_cfgmem \$Cfgmem
puts "INFO: DONE programming configuration flash."

puts "INFO: Refresh."
refresh_hw_device \$Device
puts "INFO: Done. Power-cycle the board to load the design from flash."
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
    && log::info "OK" \
    || log::error "The flash programming command failed."
