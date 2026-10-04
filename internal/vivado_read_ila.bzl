"""Vivado read ILA rule."""

load(
    "//internal:defines.bzl",
    "VIVADO_TOOLCHAIN_TYPE",
    _rlocation_path = "rlocation_path",
    _vivado_config = "vivado_config",
)
load(
    "//internal:providers.bzl",
    "VivadoBitstreamProvider",
)

def _vivado_read_ila(ctx):
    """Implementation for the vivado_read_ila rule.

    Args:
      ctx: The rule context.

    Returns:
      A DefaultInfo provider.
    """
    bitstream_provider = None
    bittarget = None
    for target in ctx.attr.deps:
        bittarget = target
        break

    bitstream_provider = bittarget[VivadoBitstreamProvider]
    probes_file = bitstream_provider.probes

    # Needed binaries
    config = _vivado_config(ctx)
    script = config.runner.executable
    gotopt2 = ctx.attr._gotopt2.files.to_list()[0]
    generator = ctx.attr._ilagen.files.to_list()[0]

    data = ctx.attr._data.files.to_list()
    for target in ctx.attr._tools:
        data += target.files.to_list()

    tpl1 = data[1]
    yaml = data[0]

    # Generated script file.
    default_runfiles = []

    outfile = ctx.actions.declare_file("{}.sh".format(ctx.attr.name))
    args = ctx.actions.args()
    args.add("--outfile", outfile.path)
    args.add("--gotopt2", gotopt2.path)
    args.add("--run-docker", script.path)
    args.add("--runner-rlocation", _rlocation_path(ctx, script))
    args.add("--template", tpl1.path)
    args.add("--ltxfile", probes_file.short_path)
    args.add("--vivado-version", config.vivado_version)
    args.add("--vivado-path", config.vivado_path)
    args.add("--container", config.container)
    args.add("--vivado-mode", config.mode)

    ctx.actions.run(
        inputs = [generator, gotopt2, script, probes_file],
        outputs = [outfile],
        executable = generator,
        tools = [
            gotopt2,
            script,
        ] + data,
        arguments = [args],
        mnemonic = "ILAGEN",
        progress_message = "Generating ILA read script: {}".format(outfile.path),
    )

    runfiles = ctx.runfiles(
        files = [script, gotopt2, yaml, probes_file],
        collect_data = True,
    )
    tools_files = []
    for target in ctx.attr._tools:
        tools_files += target.files.to_list()

    tools_runfiles = ctx.runfiles(files = tools_files, collect_data = True)

    default_runfiles += [
        config.runner_default_runfiles,
        ctx.attr._ilagen[DefaultInfo].default_runfiles,
        ctx.attr._data[DefaultInfo].default_runfiles,
        ctx.attr._gotopt2[DefaultInfo].default_runfiles,
        tools_runfiles,
    ]

    runfiles = runfiles.merge_all(default_runfiles)

    return [
        DefaultInfo(
            files = depset([outfile, yaml, gotopt2]),
            runfiles = runfiles,
            executable = outfile,
        ),
    ]

vivado_read_ila = rule(
    implementation = _vivado_read_ila,
    executable = True,
    doc = """Captures an ILA core's data into a VCD file.

`bazel run` the target. It connects to a hw_server, loads the probes of
the bitstream in `deps`, runs the ILA core and writes what it captured.

Flags:

- `--hostport`: the hw_server, often `localhost:3122`. Required.
- `--device`: the hardware target.
- `--trigger=probe=value`: compare one probe against a value, for
  example `--trigger=state=eq3'h5`. Repeat it to trigger on several
  probes; probes not named stay don't-care. A bare value, such as
  `--trigger=eq1'b1`, sets every probe, which only works when all the
  probes have the same width.
- `--trigger_file`: a file of `probe value` lines, with `#` comments,
  read before the `--trigger` flags. A relative path is relative to
  where `bazel run` was started.
- `--trigger_position`: the sample of the window at which the trigger
  lands (`CONTROL.TRIGGER_POSITION`).
- `--window_count`: the number of windows the capture depth is split
  into (`CONTROL.WINDOW_COUNT`).
- `--vcd`: the output file, `ila_data.vcd` by default.

A probe may be named with or without its bus range: `addr` and
`addr[34:0]` are the same probe. A name that matches no probe stops the
run and lists the probes of the core.
""",
    toolchains = [VIVADO_TOOLCHAIN_TYPE],
    attrs = {
        "deps": attr.label_list(
            providers = [VivadoBitstreamProvider],
            doc = "The list of deps containing bitstream/probes code",
        ),
        "_gotopt2": attr.label(
            default = "@gotopt2//:bin",
            executable = True,
            cfg = "host",
            doc = "The gotopt2 binary.",
        ),
        "_ilagen": attr.label(
            default = Label("//build/vivado/bin/ilagen"),
            executable = True,
            cfg = "host",
            doc = "The program to generate an ILA read wrapper",
        ),
        "_data": attr.label(
            default = Label("//build/vivado/bin/ilagen:data"),
            doc = "The template and flags data",
            providers = [DefaultInfo],
        ),
        "_tools": attr.label_list(
            default = [
                Label("@bazel_tools//tools/bash/runfiles"),
                Label("@fshlib//:log"),
            ],
            doc = "The list of dependencies to expand",
        ),
    },
)
