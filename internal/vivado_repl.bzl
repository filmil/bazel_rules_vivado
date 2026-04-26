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
    
    script_rlocation = ""
    runfiles_list = [docker_run]
    if ctx.file.script:
        runfiles_list.append(ctx.file.script)
        if ctx.file.script.short_path.startswith("../"):
            script_rlocation = ctx.file.script.short_path[3:]
        else:
            script_rlocation = ctx.workspace_name + "/" + ctx.file.script.short_path

    # Generate the command using the helper.
    # We'll use a placeholder for the script path and replace it in the bash script.
    cmd = _script_cmd(
        script_path = "DOCKER_RUN_PLACEHOLDER",
        dir_reference = ".",
        cache_dir = ".vivado_repl_cache",
        freeargs = ["-it", "--net=host", "-e", "HOME=/work"],
    )
    
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        substitutions = {
            "{{DOCKER_RUN_RLOCATION}}": docker_run_rlocation,
            "{{SCRIPT_RLOCATION}}": script_rlocation,
            "{{CMD}}": cmd,
            "{{VIVADO_PATH}}": VIVADO_PATH,
        },
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(files = runfiles_list).merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)
              .merge(ctx.attr._script[DefaultInfo].default_runfiles),
        ),
    ]

vivado_repl = rule(
    implementation = _vivado_repl_impl,
    executable = True,
    attrs = DOCKER_RUN_SCRIPT_ATTRS | {
        "script": attr.label(
            allow_single_file = [".tcl"],
            doc = "Optional TCL script to run on startup.",
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
