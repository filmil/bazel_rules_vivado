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

${CMD_FINAL} \
    -e DISPLAY="${DISPLAY}" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    LD_LIBRARY_PATH="{{VIVADO_PATH}}/lib/lnx64.o" \
    "{{VIVADO_PATH}}/bin/setEnvAndRunCmd.sh vivado" \
    -mode gui "$@"

# vim: ft=bash
