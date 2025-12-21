#! /usr/bin/env bash

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
set -eo pipefail

source "$(rlocation fshlib/log.bash)"
source "$(rlocation bazel_rules_bid/build/resolve_gotopt.bash)"
source "$(rlocation bazel_rules_bid/build/resolve_workspace.bash)"

if [[ "${DEBUG}" == "true" ]]; then
  env | log::prefix "[env] "
  set -x
fi

readonly _gotopt2_binary="$(resolve_gotopt2)"

# Exit quickly if the binary isn't found. This may happen if the binary location
# moves internally in bazel.
if [[ ! -f "${_gotopt2_binary}" ]]; then
  log::error "gotopt2 binary not found at: ${_binary_path}"
  ls ${_binary_path}
  exit 240
fi

GOTOPT2_OUTPUT=$($_gotopt2_binary "${@}" <<EOF
flags:
- name: "script-file"
  type: string
  help: ""
- name: "cache-dir"
  type: string
  help: ""
- name: "work-dir"
  type: string
  help: ""
- name: "vivado-path"
  type: string
  help: ""
- name: "tcl-file"
  type: string
  help: ""
EOF
)
if [[ "$?" == "11" ]]; then
  # When --help option is used, gotopt2 exits with code 11.
  exit 0
fi

# Evaluate the output of the call to gotopt2, shell vars assignment is here.
eval "${GOTOPT2_OUTPUT}"


readonly _cache="${gotopt2_cache_dir}"
readonly _work="${gotopt2_work_dir}"
readonly _script="$(cat ${gotopt2_script_file})"
readonly _vivado_path="${gotopt2_vivado_path}"
readonly _tcl="${gotopt2_tcl_file}"

set -euo pipefail
mkdir -p "${_cache}" || log::error "Could not create dir: ${_cache}"
mkdir -p "${_work}" || log::error "Could not create dir: ${_work}"
${_script} \
LD_LIBRARY_PATH="${_vivado_path}/lib/lnx64.o" \
"${_vivado_path}/bin/setEnvAndRunCmd.sh vivado" \
    -notrace -mode batch -source "${_tcl}"


# vim: ft=bash :
