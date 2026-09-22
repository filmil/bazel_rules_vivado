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

# The command runs as a transient systemd service of the user, so that the
# run owns a cgroup and nothing it starts outlives it.
#
# Vivado's hardware manager starts `cs_server -D`, which daemonises out of
# the process tree (a session of its own, reparented to init), and when its
# client hangs up leaving a socket half closed it polls that socket for ever
# at full CPU, so its own idle timeout never fires and it outlives the run.
# Three such orphans were found spinning three cores for nine days. In the
# container the docker runner gets this for free: the container ends and
# its processes with it. On the host nothing in the process tree can reach
# a daemonised child, and an exit trap is skipped when the run is killed,
# so the cgroup is the thing: the service ends when the command exits,
# however it exits, and systemd kills whatever is left in the cgroup. The
# wrapper being killed does not stop that either, since the service does
# not depend on it.
#
# `--wait` gives the command's exit status back, `--pipe` and `--pty`
# connect the caller's streams whichever kind they are, `--same-dir` keeps
# the working directory, and the environment is passed variable by
# variable, since a service inherits none. Where there is no user manager
# to ask, the command runs as it always did: silently where none could be,
# which is a Bazel sandbox or a bare CI runner with no `XDG_RUNTIME_DIR`
# in the environment, and with a warning where one should be and does not
# answer, since that is worth knowing.
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  exec bash -c "${_cmdline}"
fi
if command -v systemd-run >/dev/null 2>&1 \
    && systemctl --user show --property=Version >/dev/null 2>&1; then
  _setenv=()
  while IFS= read -r -d "" _kv; do
    _setenv+=(--setenv="${_kv}")
  done < <(env -0)
  exec systemd-run --user --wait --pipe --pty --collect --quiet --same-dir \
    --unit="rules-vivado-$$-$(date +%s%N)" "${_setenv[@]}" \
    -- bash -c "${_cmdline}"
fi
echo >&2 "host_run: no systemd user manager here; whatever the command" \
  "daemonises, such as Vivado's cs_server, will outlive it"
exec bash -c "${_cmdline}"

# vim: filetype=bash
