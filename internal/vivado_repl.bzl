"""Vivado REPL rule."""

load("//internal:defines.bzl",
    "VIVADO_PATH",
    "DOCKER_RUN_SCRIPT_ATTRS",
    _script_cmd = "script_cmd",
)

def _vivado_repl_impl(ctx):
    """Implementation for the vivado_repl rule.

    Args:
      ctx: The rule context.

    Returns:
      A DefaultInfo provider.
    """
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")

    docker_run = ctx.executable._script

    # We use rlocation to find the docker_run script at runtime.
    # For external repositories, the rlocation path is usually <repo_name>/<path>.
    # rules_bid is the repo name.
    docker_run_rlocation = "rules_bid/build/docker_run"

    # Generate the command using the helper.
    # We'll use a placeholder for the script path and replace it in the bash script.
    cmd = _script_cmd(
        script_path = "DOCKER_RUN_PLACEHOLDER",
        dir_reference = ".",
        cache_dir = ".vivado_repl_cache",
        freeargs = ["-it", "--net=host", "-e", "HOME=/work"],
    )

    script_content = """#!/usr/bin/env bash

# --- begin runfiles.bash initialization ---
# Copy-pasted from Bazel's Bash runfiles library (tools/bash/runfiles/runfiles.bash).
if [[ ! -d "${{RUNFILES_DIR:-/dev/null}}" && ! -f "${{RUNFILES_MANIFEST_FILE:-/dev/null}}" ]]; then
  if [[ -f "$0.runfiles_manifest" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
  elif [[ -f "$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
  elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
    export RUNFILES_DIR="$0.runfiles"
  fi
fi
if [[ -f "${{RUNFILES_DIR:-/dev/null}}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${{RUNFILES_DIR}}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${{RUNFILES_MANIFEST_FILE:-/dev/null}}" ]]; then
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \\
            "${{RUNFILES_MANIFEST_FILE}}" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

set -eo pipefail

DOCKER_RUN=$(rlocation {docker_run_rlocation})

if [[ ! -f "${{DOCKER_RUN}}" ]]; then
  echo >&2 "ERROR: cannot find docker_run at ${{DOCKER_RUN}}"
  exit 1
fi

# Replace the placeholder with the actual path.
CMD="{cmd}"
CMD_FINAL="${{CMD/DOCKER_RUN_PLACEHOLDER/${{DOCKER_RUN}}}}"

${{CMD_FINAL}} \\
    LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \\
    "{vivado_path}/bin/setEnvAndRunCmd.sh vivado" \\
    -mode tcl "$@"
""".format(
        docker_run_rlocation = docker_run_rlocation,
        cmd = cmd,
        vivado_path = VIVADO_PATH,
    )

    ctx.actions.write(
        output = executable,
        content = script_content,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(files = [
                docker_run,
            ]).merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles),
        ),
    ]

vivado_repl = rule(
    implementation = _vivado_repl_impl,
    executable = True,
    attrs = DOCKER_RUN_SCRIPT_ATTRS | {
        "_bash_runfiles": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
    },
)
