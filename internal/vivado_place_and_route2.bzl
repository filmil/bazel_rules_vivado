"""Vivado place and route2 rule."""

load("//internal:defines.bzl",
    "VIVADO_VERSION", "CONTAINER", "VIVADO_PATH",
    _script_cmd = "script_cmd",
    "DOCKER_RUN_SCRIPT_ATTRS",
)
load("//internal:providers.bzl",
    "VivadoSynthProvider",
    "VivadoBitstreamProvider",
)

def _vivado_place_and_route2_impl(ctx):
    """Implementation for the vivado_place_and_route2 rule.

    Args:
      ctx: The rule context.

    Returns:
      A list of providers, including DefaultInfo and VivadoBitstreamProvider.
    """
    args = ctx.actions.args()
    name = ctx.attr.name
    generator = ctx.attr._generator.files
    generator_path = generator.to_list()[0]
    inputs = []
    outputs = []

    template_file = ctx.attr._batch_template.files.to_list()[0]
    inputs += [template_file]

    tcl_file = ctx.actions.declare_file("{}.pnr.tcl".format(name))
    outputs += [tcl_file]

    input_dcp_file = ctx.attr.synthesis[VivadoSynthProvider].synth_dcp_file

    output_dcp_file = ctx.actions.declare_file("{}.pnr.dcp".format(name))
    outputs += [output_dcp_file]
    drc_report_file = ctx.actions.declare_file("{}.drc.rpt".format(name))

    timing_summary_file = ctx.actions.declare_file("{}.timing_summary.pnr.rpt".format(name))
    outputs += [timing_summary_file]
    utilization_file = ctx.actions.declare_file("{}.utilization.pnr.rpt".format(name))
    outputs += [utilization_file]
    bit_file = ctx.actions.declare_file("{}.bit".format(name))

    xdc_files = []
    xdc_files_paths = []
    for target in ctx.attr.xdcs:
        xdc_files_paths += [ file.path for file in target.files.to_list() ]
        xdc_files += target.files.to_list()
    inputs += xdc_files

    args.add("--custom-filename", tcl_file.path)
    args.add("--custom-template", template_file.path)
    args.add("--load-dcp", input_dcp_file.path)
    args.add("--save-dcp", output_dcp_file.path)
    args.add("--timing-report", timing_summary_file.path)
    args.add("--utilization-report", utilization_file.path)
    args.add("--drc-report", drc_report_file.path)
    args.add("--top-name", name)
    args.add("--bitstream", bit_file.path)
    args.add_all(xdc_files_paths, before_each = "--constraints")

    ctx.actions.run(
        outputs = [tcl_file],
        inputs = inputs,
        tools = [ generator ],
        executable = generator_path,
        arguments = [ args ],
        progress_message = "Vivado PNR XPRGEN {}".format(name),
        mnemonic = "XPRGEN",
    )

    # PNR step here.

    # Prepare the docker mount.
    docker_run = ctx.executable._script
    env = ctx.attr.env
    mounts = {}
    if ctx.attr.mount:
      mounts.update(ctx.attr.mount)
    mounts.update({
      "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
    })

    output_dir_path = "_pnr.work.{}".format(name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    cache_dir_rpath = "_pnr.cache.{}".format(name)
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

    outputs = [output_dcp_file, drc_report_file, timing_summary_file, utilization_file, bit_file]
    inputs = [tcl_file, input_dcp_file] + xdc_files
    logfile = ctx.actions.declare_file("{}.log".format(ctx.attr.name))
    script_file = ctx.actions.declare_file("{}.script".format(ctx.attr.name))
    ctx.actions.write(script_file, content=script)
    pnr_binary = ctx.executable._pnr

    ctx.actions.run_shell(
        progress_message = "Vivado Place and Route:: {}".format(name),
        inputs = inputs + [docker_run, script_file],
        outputs = outputs + [output_dir, cache_dir, logfile],
        tools = [docker_run, pnr_binary],
        mnemonic = "VPNR2",
        command = """\
            {pnr_binary} --script-file={script} \
                --cache-dir={cache} \
                --work-dir={work} \
                --vivado-path={vivado_path} \
                --tcl-file={tcl} \
                2>&1 > {name} || (cat {name} && exit 1)
        """.format(
            pnr_binary=pnr_binary.path,
            script=script_file.path,
            vivado_path=VIVADO_PATH,
            tcl=tcl_file.path,
            cache=cache_dir.path,
            work=output_dir.path,
            name=logfile.path,
        ),
    )
    return [
        DefaultInfo(files=depset([
            bit_file,
            utilization_file,
            timing_summary_file,
            drc_report_file,
            output_dcp_file,
            logfile,
        ])),
        VivadoBitstreamProvider(
            bitstream = bit_file,
        ),
    ]

vivado_place_and_route2 = rule(
    implementation = _vivado_place_and_route2_impl,
    attrs = DOCKER_RUN_SCRIPT_ATTRS | {
        "synthesis": attr.label(
            doc = "The mandatory synth2 target to use",
            mandatory = True,
            providers = [VivadoSynthProvider],
        ),
        "xdcs": attr.label_list(
            doc = "Constraint files",
        ),
        "_generator": attr.label(
            doc = "xprgen binary",
            default = Label("//build/vivado/bin/xprgen"),
            executable = True,
            cfg = "host",
        ),
        "_pnr": attr.label(
            doc = "pnr binary",
            default = Label("//build/vivado:pnr"),
            executable = True,
            cfg = "host",
        ),
        "_batch_template": attr.label(
            doc = "pnr template",
            default = Label("//build/vivado:pnr_batch_tcl_template"),
        ),
    },
)
