"""Vivado simulation rule."""

load("//internal:defines.bzl",
    "VIVADO_VERSION", "CONTAINER", "VIVADO_PATH",
    _script_cmd = "script_cmd",
)
load("//internal:providers.bzl",
    "VivadoLibraryProvider",
)

def _vivado_simulation_impl(ctx):
    """Implementation for the vivado_simulation rule.

    Args:
      ctx: The rule context.

    Returns:
      A list of providers, including DefaultInfo and OutputGroupInfo.
    """
    args = ["-debug", "typical"]
    args += ctx.attr.xelab_args
    files = []
    # elaborate first

    provider = ctx.attr.library[VivadoLibraryProvider]
    deps_depset = provider.deps
    args += ["-L", "{}={}".format(provider.name, provider.library_dir.path)]
    for dep in provider.deps.to_list():
        dep_provider = dep
        if dep_provider.unisims_libs:
            files += [dep_provider.library_dir]
            for unisim_lib in dep_provider.deps_names.to_list():
                args += ["-L", "{lib_name}={dir_name}/{lib_name}".format(
                    lib_name=unisim_lib,
                    dir_name=dep_provider.library_dir.path)]
        else:
            files += [file for file in dep_provider.files]
            files += [dep_provider.library_dir]
            args += ["-L", "{}={}".format(
                dep_provider.name, dep_provider.library_dir.path)]

    files += [file for file in provider.files]
    files += [provider.library_dir]

    top_entity = ctx.attr.top
    if ctx.attr.config:
        top_entity = ctx.attr.config
    args += ["--top", "'{}.{}'".format(provider.name, top_entity)]
    args += ctx.attr.extra_modules

    for (k, v) in ctx.attr.defines.items():
        if v:
            # For `ifdef foo=bar
            args += ["-d", "{}={}".format(k,ctx.expand_location(v, ctx.attr.data))]
        else:
            # For `ifdef foo
            args += ["-d", "{}".format(k)]
    generic_tops = []
    for (k, v) in ctx.attr.generic_tops.items():
        # For `ifdef foo=bar
        generic_tops += ["-generic_top", '{}={}'.format(
            k,ctx.expand_location(v, ctx.attr.data))]

    data_files = []
    for target in ctx.attr.data:
        data_files += target.files.to_list()

    # The unit to elaborate.
    snapshot_name = "{}.{}.snapshot".format(provider.name, ctx.attr.top)
    args += ["--snapshot", snapshot_name]

    outputs = []
    # This is where the snapshot is located.
    xsim_dir = ctx.actions.declare_directory("{}.xsim.dir".format(ctx.label.name))
    outputs += [xsim_dir]

    # Prepare to run xelab.
    docker_run = ctx.executable._script
    env = ctx.attr.env
    mounts = {}
    if ctx.attr.mount:
      mounts.update(ctx.attr.mount)
    mounts.update({
      "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
    })

    # Outputs
    output_dir_path = "_xpr_gen.work.{}".format(ctx.label.name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    outputs += [output_dir]
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

    if ctx.attr.xelab_relaxed:
        # Relaxed checks, sometimes needed with verilog modules.
        args += ["--relax"]

    args += generic_tops
    # xelab apparently can not set the location of xsim.dir, so move it to a
    # predictable place.
    suffix = ["&&", "mv xsim.dir {}".format(xsim_dir.path)]
    compile_log = ctx.actions.declare_file("{}.log".format(ctx.attr.name))
    outputs += [compile_log]
    ctx.actions.run_shell(
        progress_message = "Vivado elaborate library \"{}\"".format(provider.name),
        inputs = files + data_files + [docker_run],
        outputs = outputs,
        mnemonic = "VivadoElab",
        tools = [docker_run],
        command = """\
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh {command} \
            {args} 2>&1 > {log} || ( cat {log} && exit 1 ) {suffix}
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            command="xelab",
            args=" ".join(args),
            suffix=" ".join(suffix),
            log=compile_log.path,
        ),
    )

    # Template script file for running xsim
    vcd_file = ctx.actions.declare_file(
        "{}.vcd".format(ctx.label.name))
    vcd_file_raw = ctx.actions.declare_file(
        "{}.raw.vcd".format(ctx.label.name))
    xsim_script_file = ctx.actions.declare_file(
        "{}.xsim.tcl".format(ctx.label.name))
    tcl_script_template = ctx.file.custom_tcl_script or ctx.file.template
    ctx.actions.expand_template(
        output = xsim_script_file,
        template = tcl_script_template,
        substitutions = {
            "{{VCD_FILE}}": vcd_file_raw.path,
            "{{TOP}}": ctx.attr.top,
        },
    )

    args = []
    args += ctx.attr.args
    inputs2 = [xsim_dir, xsim_script_file, provider.library_dir]
    #args += ["--xsimdir", "{}/xsim.dir".format(xsim_dir.path)]
    args += ["--tclbatch", xsim_script_file.path]
    outputs2 = [vcd_file_raw]
    args += ["--vcdfile", vcd_file_raw.path]
    wdb_file = ctx.actions.declare_file(
        "{}.wdb".format(ctx.label.name))
    outputs2 += [wdb_file]
    args += ["--wdb", wdb_file.path]
    args += [snapshot_name]

    # We must fix up the non-relocatability of xsim.dir.
    prefix = ["cp -R {}/xsim.dir ./xsim.dir".format(xsim_dir.path), "&&"]

    sim_log_file = ctx.actions.declare_file("{}.sim.log".format(ctx.attr.name))
    ctx.actions.run_shell(
        progress_message = "Vivado simulate \"{}.{}\"".format(provider.name, ctx.attr.top),
        inputs = inputs2 + [docker_run] + data_files ,
        outputs = outputs2 + [sim_log_file],
        mnemonic = "VivadoXsim",
        tools = [docker_run],
        command = """\
            {prefix} \
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh {command} \
            {args} 2>&1 > {log} || (cat {log} && exit 1)
        """.format(
            prefix=" ".join(prefix),
            script=script,
            vivado_path=VIVADO_PATH,
            command="xsim",
            args=" ".join(args),
            log=sim_log_file.path,
        ),
    )

    # Create raw file
    vcd_top = ctx.attr.top
    vcd_cfg = ""
    if ctx.attr.config:
        vcd_cfg = "_" + ctx.attr.config
    ctx.actions.run_shell(
        progress_message = "Fixing up VCD",
        inputs = [vcd_file_raw],
        outputs = [vcd_file],
        mnemonic = "FixVCD",
        command = """
            sed -e "s/^\\$scope module.*{top}.*{cfg}\\\\\\\\/\\$scope module {top}/g"  \\
                    < {infile} > {outfile}
        """.format(
            infile=vcd_file_raw.path, outfile=vcd_file.path,
            top=vcd_top, cfg=vcd_cfg,
        )
    )

    return [
        DefaultInfo(
          files = depset([wdb_file, vcd_file]),
        ),
        OutputGroupInfo(
            vcd = [vcd_file],
            wdb = [wdb_file],
        ),
    ]

vivado_simulation = rule(
    implementation = _vivado_simulation_impl,
    attrs = {
        "library": attr.label(
            doc = "The library to run the simulation from",
            providers = [VivadoLibraryProvider],
        ),
        "top": attr.string(
            doc = "Name of the top level entity to simulate",
        ),
        "config": attr.string(
            doc = "If specified, the said named configuration will be selected (VHDL)",
            mandatory = False,
        ),
        "extra_modules": attr.string_list(
            doc = "Names of additional modules to co-simulate",
        ),
        "defines": attr.string_dict(
            doc = "The list of key-to-value mappings to apply to the compilation",
        ),
        "generic_tops": attr.string_dict(
            doc = "The list of key-to-value mappings to apply to the compilation",
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
        "template": attr.label(
            allow_single_file = [".tcl.template"],
            default=Label("//build/vivado:xsim.tcl.template"),
            doc = "The TCL template to run.",
        ),
        "data": attr.label_list(
            doc = "A list of data targets.",
        ),
        "xelab_relaxed": attr.bool(
            doc = "Relax HDL checks, sometimes needed for Verilog modules",
        ),
        "custom_tcl_script": attr.label(
            doc = "Custom TCL script to run simulation with",
            allow_single_file = True,
            mandatory = False,
        ),
        "args": attr.string_list(
            doc = "Custom args to xsim",
            mandatory = False,
            default = [],
        ),
        "xelab_args": attr.string_list(
            doc = "Custom args to elaboration step",
            mandatory = False,
            default = [],
        ),
    },
)
