#! /bin/bash
# GENERATED FILE DO NOT EDIT
#
# Generated as:  {{ .Outfile }}
# From template: {{ .TemplateFile }}
#
set -eo pipefail 

readonly _this_dir="${0%/*}"

# These should be immune to path changes.
readonly _run_docker="external/bazel_rules_bid/build/docker_run.sh"
readonly _gotopt2="external/gotopt2/cmd/gotopt2/gotopt2_/gotopt2"
readonly _yaml_config="external/rules_vivado/build/vivado/bin/proggen/flags.yaml"
readonly _bitfile="{{ .BitFile }}"
GOTOPT2_OUTPUT=$($_gotopt2 $@ < $_yaml_config)
if [[ "$?" == "11" ]]; then
  # When --help option is used, gotopt2 exits with code 11.
  exit 1
fi

eval "${GOTOPT2_OUTPUT}"

if [[ "${gotopt2_hostport}" == "" ]]; then
    echo "--hostport is required"
    exit 1
fi

if [[ "${gotopt2_device}" == "" ]]; then
    echo "--device is required"
    exit 1
fi

readonly _tcl_script_file="prog.tcl"

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

# Program and Refresh the XC7K325T Device
set Device [lindex [get_hw_devices] 0]
current_hw_device \$Device
refresh_hw_device -update_hw_probes false \$Device

set_property PROGRAM.FILE "{{ .BitFile }}" \$Device

#set_property PROBES.FILE "C:/design.ltx" \$Device

puts "INFO: Programming device with bitstream: {{ .BitFile }}"
program_hw_devices \$Device
puts "INFO: DONE Programming device."

puts "INFO: Refresh."
refresh_hw_device \$Device
puts "INFO: Done."
EOF

env RUNFILES_DIR="$PWD/.." \
"${_run_docker}" \
    --container=xilinx-vivado:latest \
    --dir-reference=${PWD} \
    --source-dir=${PWD} \
    --scratch-dir=${PWD}:/.cache \
    --mounts=/tmp/.X11-unix:/tmp/.X11-unix:ro \
    --freeargs=--net=host,-e,HOME=/work,-w,/work \
    --src-mount=/work \
    LD_LIBRARY_PATH="/opt/Xilinx/Vivado/2023.2/lib/lnx64.o" \
    /opt/Xilinx/Vivado/2023.2/bin/setEnvAndRunCmd.sh vivado \
    -notrace -mode batch \
    -source "/work/${_tcl_script_file}"

