load("//internal:providers.bzl", "VivadoSimulationProvider")
"""Vivado view rule."""

load("//internal:defines.bzl",
    "DOCKER_RUN_SCRIPT_ATTRS",
    "VIVADO_CONFIG_ATTRS",
    _script_cmd = "script_cmd",
    _vivado_config = "vivado_config",
)

def _vivado_view_impl(ctx):
    """Implementation for the vivado_view rule.

    Args:
      ctx: The rule context.

    Returns:
      A DefaultInfo provider.
    """
    config = _vivado_config(ctx)
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")

    docker_run = ctx.executable._script

    # We use rlocation to find the docker_run script at runtime.
    docker_run_rlocation = ""
    if docker_run.short_path.startswith("../"):
        docker_run_rlocation = docker_run.short_path[3:]
    else:
        docker_run_rlocation = ctx.workspace_name + "/" + docker_run.short_path

    # Find the wdb file and snapshot name
    wdb_file = None
    snapshot_name = ""
    xsim_dir = None
    if VivadoSimulationProvider in ctx.attr.dep:
        prov = ctx.attr.dep[VivadoSimulationProvider]
        wdb_file = prov.wdb
        snapshot_name = prov.snapshot_name
        xsim_dir = prov.xsim_dir
    
    if not wdb_file:
        if OutputGroupInfo in ctx.attr.dep:
            if hasattr(ctx.attr.dep[OutputGroupInfo], "wdb"):
                wdb_files = ctx.attr.dep[OutputGroupInfo].wdb.to_list()
                if wdb_files:
                    wdb_file = wdb_files[0]

    if not wdb_file:
        for file in ctx.attr.dep.files.to_list():
            if file.extension == "wdb":
                wdb_file = file
                break

    if not wdb_file:
        fail("Could not find a .wdb file in the provided dependency.")

    wdb_file_rlocation = ""
    if wdb_file.short_path.startswith("../"):
        wdb_file_rlocation = wdb_file.short_path[3:]
    else:
        wdb_file_rlocation = ctx.workspace_name + "/" + wdb_file.short_path

    xsim_dir_rlocation = ""
    if xsim_dir:
        if xsim_dir.short_path.startswith("../"):
            xsim_dir_rlocation = xsim_dir.short_path[3:]
        else:
            xsim_dir_rlocation = ctx.workspace_name + "/" + xsim_dir.short_path

    # Find a .wcfg file if provided in data
    wcfg_file = None
    for data_target in ctx.attr.data:
        for file in data_target.files.to_list():
            if file.extension == "wcfg":
                wcfg_file = file
                break

    wcfg_file_rlocation = ""
    if wcfg_file:
        if wcfg_file.short_path.startswith("../"):
            wcfg_file_rlocation = wcfg_file.short_path[3:]
        else:
            wcfg_file_rlocation = ctx.workspace_name + "/" + wcfg_file.short_path

    runfiles_list = [docker_run, wdb_file]
    if xsim_dir: runfiles_list.append(xsim_dir)
    for data_target in ctx.attr.data:
        for file in data_target.files.to_list():
            runfiles_list.append(file)

    # Generate the command using the helper.
    cmd = _script_cmd(
        script_path = "DOCKER_RUN_PLACEHOLDER",
        dir_reference = ".",
        cache_dir = ".vivado_view_cache",
        freeargs = ["-it", "--net=host"],
        container = config.container,
    )

    ctx.actions.expand_template(
        template = ctx.file._template,
        output = executable,
        substitutions = {
            "{{DOCKER_RUN_RLOCATION}}": docker_run_rlocation,
            "{{WDB_FILE_RLOCATION}}": wdb_file_rlocation,
            "{{CMD}}": cmd,
            "{{SNAPSHOT_NAME}}": snapshot_name,
            "{{WCFG_FILE_RLOCATION}}": wcfg_file_rlocation,
            "{{XSIM_DIR_RLOCATION}}": xsim_dir_rlocation,
            "{{ARGS}}": "",
            "{{VIVADO_PATH}}": config.vivado_path,
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

vivado_view = rule(
    implementation = _vivado_view_impl,
    executable = True,
    doc = """Opens a Vivado simulator GUI (xsim) for a generated waveform database (wdb) file.

Example:
```bzl
load("@bazel_rules_vivado//build/vivado:rules.bzl", "vivado_simulation", "vivado_view")

vivado_simulation(
    name = "my_simulation",
    top = "my_top_module",
    # ...
)

vivado_view(
    name = "my_simulation_view",
    dep = ":my_simulation",
    data = ["//path/to/my:custom_waveform_config.wcfg"],
)
```
""",
    attrs = DOCKER_RUN_SCRIPT_ATTRS | VIVADO_CONFIG_ATTRS | {
        "dep": attr.label(
            doc = "The dependency that generates the wdb file (e.g. vivado_simulation).",
            mandatory = True,
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "A list of data targets to pass into the sandbox.",
        ),
        "_bash_runfiles": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
        "_template": attr.label(
            default = "//internal:vivado_view.sh.tpl",
            allow_single_file = True,
        ),
    },
)
