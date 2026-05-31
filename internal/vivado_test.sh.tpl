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

XSIM_DIR=$(rlocation {{XSIM_DIR_RLOCATION}})
if [[ ! -d "${XSIM_DIR}" ]]; then
  echo >&2 "ERROR: cannot find xsim.dir at ${XSIM_DIR}"
  exit 1
fi

# xsim is not relocatable, so we must copy xsim.dir to the current directory.
# But wait, it might already be here if we are lucky, but better safe than sorry.
if [[ ! -d "xsim.dir" ]]; then
    cp -R "${XSIM_DIR}/xsim.dir" ./xsim.dir
fi

XSIM_TCL=$(rlocation {{XSIM_TCL_RLOCATION}})
if [[ ! -f "${XSIM_TCL}" ]]; then
  echo >&2 "ERROR: cannot find xsim TCL script at ${XSIM_TCL}"
  exit 1
fi

# We need to recreate the library structure or use an xsim.ini file.
# For now, let's try to copy/symlink libraries to their expected paths.
# The expected paths are those used during xelab.

{{LIBRARY_SYMLINKS}}

# Replace the placeholder with the actual path.
CMD="{{CMD}}"
CMD_FINAL="${CMD/DOCKER_RUN_PLACEHOLDER/${DOCKER_RUN}}"

# Run xsim
${CMD_FINAL} \
    LD_LIBRARY_PATH="{{VIVADO_PATH}}/lib/lnx64.o" \
    "{{VIVADO_PATH}}/bin/setEnvAndRunCmd.sh xsim" \
    --tclbatch "${XSIM_TCL}" \
    {{XSIM_ARGS}} \
    {{SNAPSHOT_NAME}}
