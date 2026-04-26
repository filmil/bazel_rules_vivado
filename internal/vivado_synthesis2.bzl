"""Vivado synthesis2 rule."""

load("//internal:defines.bzl",
    "VIVADO_VERSION", "CONTAINER", "VIVADO_PATH",
    _script_cmd = "script_cmd",
    "DOCKER_RUN_SCRIPT_ATTRS",
)
load("//internal:providers.bzl",
    "VivadoLibraryProvider",
    "VivadoSynthProvider",
)

def _vivado_synthesis2_impl(ctx):
    """Implementation for the vivado_synthesis2 rule.

    Args:
      ctx: The rule context.

    Returns:
      A list of providers, including DefaultInfo and VivadoSynthProvider.
    """
    args = ctx.actions.args()

    # General setup
    name = ctx.attr.name
    top_level = ctx.attr.top

    # Get tool path
    generator = ctx.attr._generator.files
    generator_path = generator.to_list()[0]

    # Why is this data model so complicated?!
    inputs = []
    outputs = []
    deps_files = []
    srcs_files = []
    hdrs_files = []
    xdcs_files = []

    # Template file.
    template_file = ctx.attr._synth_batch_template.files.to_list()[0]
    inputs += [template_file]

    # Get library deps.
    seen_libraries = []
    for dep in ctx.attr.deps:
        provider = dep[VivadoLibraryProvider]

        for provider_dep in provider.deps.to_list():
            lib_name = provider_dep.name
            if lib_name not in seen_libraries:
                seen_libraries += [lib_name]

                provider_dep_files = provider_dep.files
                for file in provider_dep_files:
                    inputs += [file]
                    deps_files += [file]
                    args.add("--library-file", "{}={}".format(lib_name, file.path))

        lib_name = provider.name
        if lib_name not in seen_libraries:
            seen_libraries += [lib_name]

            for file in provider.files:
                inputs += [file]
                deps_files += [file]
                args.add("--library-file", "{}={}".format(lib_name, file.path))

    # Process srcs
    for src_target in ctx.attr.srcs:
        srcs_files += src_target.files.to_list()
    inputs += srcs_files
    src_paths = [ f.path for f in srcs_files ]

    # Process hdrs
    for hdrs_target in ctx.attr.hdrs:
        hdrs_files += hdrs_target.files.to_list()
    inputs += hdrs_files
    hdrs_paths = [ f.path for f in hdrs_files ]

    # Process constraints files (.xdc)
    for xdcs_target in ctx.attr.xdcs:
        xdcs_files += xdcs_target.files.to_list()
    inputs += xdcs_files
    xdcs_paths = [ f.path for f in xdcs_files ]
    # Prepare include dirs
    include_dirs = ctx.attr.include_dirs  # list(string)

    # Handle output files
    dcp_file = ctx.actions.declare_file("{}.dcp".format(name))
    outputs += [dcp_file]

    timing_summary_file = ctx.actions.declare_file("{}.timing_summary_synth.rpt".format(name))
    outputs += [timing_summary_file]
    utilization_file = ctx.actions.declare_file("{}.utilization_synth.rpt".format(name))
    outputs += [utilization_file]

    tcl_file = ctx.actions.declare_file("{}.synth.tcl".format(name))

    processed_defines = []
    for k, v in ctx.attr.defines.items():
        expanded = ctx.expand_location(v, targets = ctx.attr.data)
        processed_defines += ["{}={}".format(k, expanded)]
    processed_generics = []
    for k, v in ctx.attr.generics.items():
        expanded = ctx.expand_location(v, targets = ctx.attr.data)
        processed_generics += ["{}={}".format(k, expanded)]

    # data_files = [ file for file in target.files.to_list() for target in ctx.attr.data ]
    # ???
    data_files = []
    for target in ctx.attr.data:
        for file in target.files.to_list():
            data_files += [file]
    inputs += data_files


    # Prepare args
    args.add("--custom-filename", tcl_file.path)
    args.add("--custom-template", template_file.path)
    args.add("--project-name", name)
    args.add("--save-dcp", dcp_file.path)
    args.add("--timing-report", timing_summary_file.path)
    args.add("--top-name", top_level)
    args.add("--utilization-report", utilization_file.path)
    args.add_all(processed_defines, before_each="--define")
    args.add_all(processed_generics, before_each="--generic")
    args.add_all(hdrs_paths, before_each="--header")
    args.add_all(include_dirs, before_each="--include-dir")
    args.add_all(src_paths, before_each="--source")
    args.add_all(xdcs_paths, before_each="--constraints")


    part = ctx.attr.part
    args.add("--part", part)

    # Generate `tcl_file` script for running the synth step.
    ctx.actions.run(
        outputs = [tcl_file],
        inputs = inputs,
        tools = [ generator ],
        executable = generator_path,
        arguments = [ args ],
        progress_message = "Vivado Synth XPRGEN {}".format(name),
        mnemonic = "XPRGEN",
    )

    # Prepare the docker mount.
    docker_run = ctx.executable._script
    env = ctx.attr.env
    mounts = {}
    if ctx.attr.mount:
      mounts.update(ctx.attr.mount)
    mounts.update({
      "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
    })

    output_dir_path = "_synthesis.work.{}".format(name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    cache_dir_rpath = "_synthesis.cache.{}".format(name)
    cache_dir = ctx.actions.declare_directory(cache_dir_rpath)

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

    inputs += [tcl_file]
    logfile = ctx.actions.declare_file("{}.log".format(name))
    outputs += [logfile]

    ctx.actions.run_shell(
        progress_message = "Vivado Synthesis {}".format(name),
        inputs = inputs + [docker_run],
        outputs = outputs + [output_dir, cache_dir],
        tools = [docker_run],
        mnemonic = "VSYN2",
        command = """\
            mkdir -p {cache} &&
            mkdir -p {work} && \
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh vivado \
                -notrace -mode batch -source {synth_tcl} \
                2>&1 > {name} || (cat {name} && exit 1)
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            synth_tcl=tcl_file.path,
            cache=cache_dir.path,
            work=output_dir.path,
            name=logfile.path,
        ),
    )

    return [
        DefaultInfo(
            # DCP outfile, plus reports.
            files = depset(outputs),
        ),
        VivadoSynthProvider(
            synth_dcp_file = dcp_file,
        ),
    ]

vivado_synthesis2 = rule(
    implementation = _vivado_synthesis2_impl,
    attrs = DOCKER_RUN_SCRIPT_ATTRS | {
        "srcs": attr.label_list(
            allow_files = True,
            doc = "The sources for the `work` library",
        ),
        "hdrs": attr.label_list(
            doc = "The headers for the `work` library if verilog",
        ),
        "deps": attr.label_list(
            doc = "The sources for the libraries",
            providers = [VivadoLibraryProvider],
        ),
        "data": attr.label_list(
            doc = "Other data",
        ),
        "xdcs": attr.label_list(
            doc = "Constraint files",
        ),
        "top": attr.string(
            doc = "Mandatory name of the top level entity",
            mandatory = True,
        ),
        "part": attr.string(
            doc = "The part that is targeted by this project",
            mandatory = True,
        ),
        "defines": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of defines.",
        ),
        "generics": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of generics.",
        ),
        "include_dirs": attr.string_list(
            allow_empty = True,
            doc = "A list of include directories.",
        ),
        "_generator": attr.label(
            doc = "xprgen binary",
            default = Label("//build/vivado/bin/xprgen"),
            executable = True,
            cfg = "host",
        ),
        "_synth_batch_template": attr.label(
            doc = "synth template",
            default = Label("//build/vivado:synth_batch_tcl_template"),
        ),
        # Probably need verilog top level params and vhdl top level generics.
    },
)
