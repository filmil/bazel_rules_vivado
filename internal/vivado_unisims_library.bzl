"""Vivado unisims library rule."""

load("//internal:defines.bzl",
    "VIVADO_VERSION", "CONTAINER", "VIVADO_PATH",
    _script_cmd = "script_cmd",
)
load("//internal:providers.bzl",
    "VivadoLibraryProvider",
)

def _vivado_unisims_library_impl(ctx):
    """Implementation for the vivado_unisims_library rule.

    Args:
      ctx: The rule context.

    Returns:
      A list of providers, including DefaultInfo and VivadoLibraryProvider.
    """
    # General
    name = ctx.attr.name
    docker_run = ctx.executable._script
    env = ctx.attr.env
    mounts = {}
    if ctx.attr.mount:
      mounts.update(ctx.attr.mount)
    mounts.update({
      "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
    })

    # Outputs
    output_dir_path = "_xpr_gen.work.{}".format(name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    outputs = [output_dir]

    cache_dir = ctx.actions.declare_directory(
      "_xpr_gen.cache.{}".format(ctx.label.name))
    outputs += [cache_dir]

    script = _script_cmd(
      docker_run.path,
      output_dir.path,
      cache_dir.path,
      envs=",".join(["{}={}".format(k, v) for (k,v) in env.items()]),
      mounts=",".join(["{}:{}".format(k, v) for (k,v) in mounts.items()]),
      freeargs=[
        "--net=host",
        "-e", "HOME=/work",
      ],
    )
    output_dir2 = ctx.actions.declare_directory("{}.unisims.top".format(ctx.label.name))
    outputs += [output_dir2]

    inputs = []
    compile_script_file = ctx.actions.declare_file(
        "{}.compile.tcl".format(ctx.label.name))
    inputs += [compile_script_file]

    bool_flags = []
    if ctx.attr.force:
        bool_flags += ["-force"]
    if ctx.attr.quiet:
        bool_flags += ["-quiet"]
    if ctx.attr.verbose:
        bool_flags += ["-verbose"]
    if ctx.attr.no_ip_compile:
        bool_flags += ["-no_ip_compile"]
    if ctx.attr.no_systemc_compile:
        bool_flags += ["-no_systemc_compile"]

    libraries = []
    for lib in ctx.attr.libraries:
        libraries+= ["-library", lib]

    ctx.actions.expand_template(
        output = compile_script_file,
        template = ctx.attr.template.files.to_list()[0],
        substitutions = {
            "{{COMMENT}}": "Generated file do not edit.",
            "{{SIMULATOR}}": ctx.attr.simulator,
            "{{FAMILY}}": ctx.attr.family,
            "{{LANGUAGE}}": ctx.attr.language,
            "{{OUTPUT_DIR}}": output_dir2.path,
            "{{LIBRARIES}}": " ".join(libraries),
            "{{SKIP_LIBRARIES}}": " ".join(ctx.attr.skip_libraries),
            "{{BOOL_FLAGS}}": " ".join(bool_flags),
        },
    )
    #args = ["-batch", compile_script_file.path]
    args = ["-mode", "batch", "-script", compile_script_file.path]
    unisims_log = ctx.actions.declare_file(
        "{}.unisims.log".format(ctx.label.name))
    outputs += [unisims_log]
    ctx.actions.run_shell(
        progress_message = "Vivado compile unisims {}.{}.{}".format(
            ctx.label.name, ctx.attr.family, ctx.attr.language),
        inputs = inputs + [docker_run],
        outputs = outputs,
        mnemonic = "VivadoXsim",
        tools = [docker_run],
        command = """\
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh {command} \
            {args} 2>&1 > {log} || ( cat {log} && exit 1)
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            command="vivado",
            args=" ".join(args),
            log=unisims_log.path,
        ),
    )
    return [
        DefaultInfo(files=depset([output_dir2])),
        VivadoLibraryProvider(
            name="(unisims bundle)",
            files=[],
            hdrs=[],
            includes=[],
            deps=depset([]),
            deps_names=depset(ctx.attr.export_libraries),
            library_dir=output_dir2,
            unisims_libs=True,
        ),
    ]


vivado_unisims_library = rule(
    implementation = _vivado_unisims_library_impl,
    # Options of the compile_simlib script.
    # See: https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/compile_simlib
    attrs = {
        "simulator": attr.string(
            default = "xsim",
            doc = "Name of the top level entity to simulate",
        ),
        "language": attr.string(
            default = "vhdl",
            doc = "The language to compile for: vhdl|verilog|all",
        ),
        "family": attr.string(
            default = "artix7",
            doc = "The device family to compile the library for.",
        ),
        "libraries": attr.string_list(
            default = ["unisim"],
            doc = "The libraries to compile: unisim|simprim|...|all",
        ),
        "export_libraries": attr.string_list(
            default = ["unisim", "unimacro", "unifast"],
            doc = "The libraries to make available to users.",
        ),
        "force": attr.bool(
            default = False,
            doc = "Whether to force compilation.",
        ),
        "quiet": attr.bool(
            default = False,
            doc = "Whether to be quiet.",
        ),
        "verbose": attr.bool(
            default = False,
            doc = "Whether to be verbose.",
        ),
        "no_ip_compile": attr.bool(
            default = False,
            doc = "Whether to skip IP compile.",
        ),
        "no_systemc_compile": attr.bool(
            default = False,
            doc = "Whether to skip SystemC compile.",
        ),
        "skip_libraries": attr.string_list(
            default = [],
            doc = "The list of libraries to skip.",
        ),
        "template": attr.label(
            allow_single_file = True,
            default = Label("//build/vivado:compile_simlib.tcl.template"),
            doc = "The template for the compile_simlib script.",
        ),
        # These parameters are part of the docker_run setup.
        "env": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of env variables to define for the run."
        ),
        "mount": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of mounts to define for the run."
        ),
        "_script": attr.label(
            default="@rules_bid//build:docker_run",
            executable=True,
            cfg="host",
            doc = "The docker run script.",
        ),
    },
)
