"""Vivado REPL rule."""

load("//internal:defines.bzl",
    "DOCKER_RUN_SCRIPT_ATTRS",
    "VIVADO_CONFIG_ATTRS",
    _script_cmd = "script_cmd",
    _vivado_config = "vivado_config",
)

def _vivado_repl_impl(ctx):
    """Implementation for the vivado_repl rule.

    Args:
      ctx: The rule context.

    Returns:
      A DefaultInfo provider.
    """
    config = _vivado_config(ctx)
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")

    docker_run = ctx.executable._script
    
    # We use rlocation to find the docker_run script at runtime.
    # For external repositories, the rlocation path is usually <repo_name>/<path>.
    docker_run_rlocation = ""
    if docker_run.short_path.startswith("../"):
        docker_run_rlocation = docker_run.short_path[3:]
    else:
        docker_run_rlocation = ctx.workspace_name + "/" + docker_run.short_path
    
    script_rlocation = ""
    runfiles_list = [docker_run]
    if ctx.file.script:
        runfiles_list.append(ctx.file.script)
        if ctx.file.script.short_path.startswith("../"):
            script_rlocation = ctx.file.script.short_path[3:]
        else:
            script_rlocation = ctx.workspace_name + "/" + ctx.file.script.short_path

    # `data` files are placed in the runfiles tree, which is mounted into the
    # container as the working directory, so they are available to the REPL.
    runfiles_list += ctx.files.data

    # `-it` gives docker an interactive TTY (needed for the interactive REPL),
    # but fails when there is no TTY (e.g. piped input or CI). `use_terminal`
    # lets callers drop it.
    freeargs = ["--net=host", "-e", "HOME=/work"]
    if ctx.attr.use_terminal:
        freeargs = ["-it"] + freeargs

    # Generate the command using the helper.
    # We'll use a placeholder for the script path and replace it in the bash script.
    cmd = _script_cmd(
        script_path = "DOCKER_RUN_PLACEHOLDER",
        dir_reference = ".",
        cache_dir = ".vivado_repl_cache",
        freeargs = freeargs,
        container = config.container,
    )

    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        substitutions = {
            "{{DOCKER_RUN_RLOCATION}}": docker_run_rlocation,
            "{{SCRIPT_RLOCATION}}": script_rlocation,
            "{{CMD}}": cmd,
            "{{VIVADO_PATH}}": config.vivado_path,
        },
        is_executable = True,
    )

    runfiles = (
        ctx.runfiles(files = runfiles_list)
            .merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)
            .merge(ctx.attr._script[DefaultInfo].default_runfiles)
    )
    for d in ctx.attr.data:
        runfiles = runfiles.merge(d[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            executable = executable,
            runfiles = runfiles,
        ),
    ]

vivado_repl = rule(
    implementation = _vivado_repl_impl,
    executable = True,
    attrs = DOCKER_RUN_SCRIPT_ATTRS | VIVADO_CONFIG_ATTRS | {
        "script": attr.label(
            allow_single_file = [".tcl"],
            doc = "Optional TCL script to run on startup.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Files (or targets whose default outputs and runfiles) to " +
                  "make available in the REPL's working directory inside the " +
                  "container.",
        ),
        "use_terminal": attr.bool(
            default = True,
            doc = "If true (default), run the container with `-it` so Vivado " +
                  "gets an interactive TTY. Set to false for non-interactive " +
                  "contexts (e.g. piped input or CI), where `-it` would fail " +
                  "with 'the input device is not a TTY'.",
        ),
        "_bash_runfiles": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
        "_template": attr.label(
            default = "//internal:vivado_repl.sh.tpl",
            allow_single_file = True,
        ),
    },
)
