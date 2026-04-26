"""Vivado GUI rule."""

load("//internal:defines.bzl",
    "VIVADO_PATH",
    "DOCKER_RUN_SCRIPT_ATTRS",
    _script_cmd = "script_cmd",
)

def _vivado_gui_impl(ctx):
    """Implementation for the vivado_gui rule.

    Args:
      ctx: The rule context.

    Returns:
      A DefaultInfo provider.
    """
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")

    docker_run = ctx.executable._script

    # We use rlocation to find the docker_run script at runtime.
    docker_run_rlocation = "rules_bid/build/docker_run"

    # Generate the command using the helper.
    cmd = _script_cmd(
        script_path = "DOCKER_RUN_PLACEHOLDER",
        dir_reference = ".",
        cache_dir = ".vivado_gui_cache",
        freeargs = ["-it", "--net=host"],
    )

    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        substitutions = {
            "{{DOCKER_RUN_RLOCATION}}": docker_run_rlocation,
            "{{CMD}}": cmd,
            "{{VIVADO_PATH}}": VIVADO_PATH,
        },
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(files = [
                docker_run,
            ]).merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)
              .merge(ctx.attr._script[DefaultInfo].default_runfiles),
        ),
    ]

vivado_gui = rule(
    implementation = _vivado_gui_impl,
    executable = True,
    attrs = DOCKER_RUN_SCRIPT_ATTRS | {
        "_bash_runfiles": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
        "_template": attr.label(
            default = "//internal:vivado_gui.sh.tpl",
            allow_single_file = True,
        ),
    },
)
