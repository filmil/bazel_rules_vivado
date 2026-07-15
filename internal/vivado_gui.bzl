"""Vivado GUI rule."""

load(
    "//internal:defines.bzl",
    "DOCKER_RUN_SCRIPT_ATTRS",
    "VIVADO_TOOLCHAIN_TYPE",
    _rlocation_path = "rlocation_path",
    _script_cmd = "script_cmd",
    _vivado_config = "vivado_config",
)

def _vivado_gui_impl(ctx):
    """Implementation for the vivado_gui rule.

    Args:
      ctx: The rule context.

    Returns:
      A DefaultInfo provider.
    """
    config = _vivado_config(ctx)
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")

    runner = config.runner

    # We use rlocation to find the runner script at runtime.
    docker_run_rlocation = _rlocation_path(ctx, runner.executable)

    script_rlocation = ""
    runfiles_list = [runner.executable]
    if ctx.file.script:
        runfiles_list.append(ctx.file.script)
        if ctx.file.script.short_path.startswith("../"):
            script_rlocation = ctx.file.script.short_path[3:]
        else:
            script_rlocation = ctx.workspace_name + "/" + ctx.file.script.short_path

    # Generate the command using the helper.
    cmd = _script_cmd(
        script_path = "DOCKER_RUN_PLACEHOLDER",
        dir_reference = ".",
        cache_dir = ".vivado_gui_cache",
        freeargs = ["-it", "--net=host"],
        container = config.container,
    )

    # In docker mode HOME points at a directory that is bind-mounted into the
    # container; in host mode the local home directory is used as is.
    gui_envs = "DISPLAY=${DISPLAY},HOME=/home/vivado"
    if config.is_host:
        gui_envs = "DISPLAY=${DISPLAY},HOME=${VIVADO_HOME_DIR}"

    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        substitutions = {
            "{{DOCKER_RUN_RLOCATION}}": docker_run_rlocation,
            "{{SCRIPT_RLOCATION}}": script_rlocation,
            "{{CMD}}": cmd,
            "{{GUI_ENVS}}": gui_envs,
            "{{VIVADO_PATH}}": config.vivado_path,
        },
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(files = runfiles_list).merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)
                .merge(config.runner_default_runfiles),
        ),
    ]

vivado_gui = rule(
    implementation = _vivado_gui_impl,
    executable = True,
    toolchains = [VIVADO_TOOLCHAIN_TYPE],
    attrs = DOCKER_RUN_SCRIPT_ATTRS | {
        "script": attr.label(
            allow_single_file = [".tcl"],
            doc = "Optional TCL script to run on startup.",
        ),
        "_bash_runfiles": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
        "_template": attr.label(
            default = "//internal:vivado_gui.sh.tpl",
            allow_single_file = True,
        ),
    },
)
