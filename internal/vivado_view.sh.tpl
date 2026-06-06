#!/usr/bin/env bash

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
            "${RUNFILES_MANIFEST_FILE}" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

set -eo pipefail

DOCKER_RUN=$(rlocation {{DOCKER_RUN_RLOCATION}})

if [[ ! -f "${DOCKER_RUN}" ]]; then
  echo >&2 "ERROR: cannot find docker_run at ${DOCKER_RUN}"
  exit 1
fi

# Replace the placeholder with the actual path.
CMD="{{CMD}}"
CMD_FINAL="${CMD/DOCKER_RUN_PLACEHOLDER/${DOCKER_RUN}}"

# Ensure DISPLAY is set.
if [[ -z "${DISPLAY}" ]]; then
  echo >&2 "WARNING: DISPLAY is not set. GUI might not start correctly."
fi

# Create a local home directory to give Vivado write access for its configs.
VIVADO_HOME_DIR="${PWD}/.vivado_home"
mkdir -p "${VIVADO_HOME_DIR}"
chmod a+w "${VIVADO_HOME_DIR}"

WDB_FILE=$(rlocation {{WDB_FILE_RLOCATION}})
WCFG_FILE_PATH=$(rlocation {{WCFG_FILE_RLOCATION}})
XSIM_DIR_PATH=$(rlocation {{XSIM_DIR_RLOCATION}})

# Create a writable work directory.
WORK_DIR="${PWD}/.vivado_view_work"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

# Copy xsim.dir to the work directory and make it writable.
if [[ -d "${XSIM_DIR_PATH}/xsim.dir" ]]; then
    cp -R "${XSIM_DIR_PATH}/xsim.dir" "${WORK_DIR}/"
    chmod -R +w "${WORK_DIR}/xsim.dir"
fi

# Copy the WDB file.
if [[ -f "${WDB_FILE}" ]]; then
    cp "${WDB_FILE}" "${WORK_DIR}/sim.wdb"
fi

# Copy WCFG if present.
WCFG_IN_WORK=""
if [[ -n "${WCFG_FILE_PATH}" && -f "${WCFG_FILE_PATH}" ]]; then
    cp "${WCFG_FILE_PATH}" "${WORK_DIR}/view.wcfg"
    WCFG_IN_WORK="view.wcfg"
fi

# Create the TCL script.
cat <<TCL > "${WORK_DIR}/view.tcl"
if { [file exists sim.wdb] } {
    open_wave_database sim.wdb
}
if { "${WCFG_IN_WORK}" != "" } {
    open_wave_config "${WCFG_IN_WORK}"
}
TCL

# Change to the work directory.
cd "${WORK_DIR}"

${CMD_FINAL} \
    --envs="DISPLAY=${DISPLAY},HOME=/home/vivado" \
    --mounts="/tmp/.X11-unix:/tmp/.X11-unix,${VIVADO_HOME_DIR}:/home/vivado:rw" \
    -- \
    LD_LIBRARY_PATH="{{VIVADO_PATH}}/lib/lnx64.o" \
    "{{VIVADO_PATH}}/bin/setEnvAndRunCmd.sh" xsim \
    {{SNAPSHOT_NAME}} -gui -tclbatch view.tcl {{ARGS}} "$@"

# vim: ft=bash
