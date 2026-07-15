#! /usr/bin/env bash

# Runs a command line directly on the host.
#
# This is the host-execution counterpart of `@rules_bid//build:docker_run`.
# It accepts the same command line flags as docker_run.sh, so the two runners
# are interchangeable: rule implementations generate a single command line and
# the Vivado toolchain decides which runner executes it (see
# //internal:toolchain.bzl).
#
# Docker-specific flags (--container, --mounts, --freeargs, ...) are parsed
# and ignored. `--envs` is honored by exporting the key=value pairs into the
# command's environment. The command tail is executed on the host via
# `bash -c`, mirroring how docker_run.sh executes it inside the container.
#
# Example use:
#
#    ./host_run.sh --container=ignored:tag --envs=FOO=bar \
#        command arg1 arg2 arg3

set -eo pipefail

_envs=()
_scratch_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --envs=*)
      IFS=',' read -r -a _envs <<< "${1#--envs=}"
      shift
      ;;
    --scratch-dir=*)
      _scratch_dir="${1#--scratch-dir=}"
      shift
      ;;
    --)
      shift
      break
      ;;
    --*)
      # All other flags are docker_run.sh flags that have no meaning on the
      # host (--container, --dir-reference, --mounts, --freeargs, --tools,
      # --source-dir, --src-mount, --src-dir-hint, ...). Ignore them.
      shift
      ;;
    *)
      break
      ;;
  esac
done

# The scratch dir is a docker mount expression `host_dir:container_dir`.
# Only the host part is relevant here; make sure it exists and is writable,
# mirroring docker_run.sh behavior.
if [[ "${_scratch_dir}" != "" ]]; then
  _scratch_host_dir="${_scratch_dir%:*}"
  mkdir -p "${_scratch_host_dir}"
  chmod a+w "${_scratch_host_dir}" || true
fi

# Vivado insists on a writable HOME (for ~/.Xilinx and friends). In the
# container HOME is redirected to the mounted work directory; on the host the
# current working directory (the Bazel exec root or runfiles dir) plays that
# role. An explicit HOME in --envs takes precedence.
export HOME="${PWD}"

for _kv in "${_envs[@]}"; do
  export "${_kv?}"
done

# Join the remaining args with spaces and re-parse them through `bash -c`,
# exactly like docker_run.sh does inside the container. This makes quoted
# multi-word arguments (e.g. "path/setEnvAndRunCmd.sh vivado") behave
# identically under both runners.
readonly _cmdline="$*"

exec bash -c "${_cmdline}"

# vim: filetype=bash
