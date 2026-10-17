"""Vivado program device rule."""

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

def _vivado_program_device(ctx):
    """Implementation for the vivado_program_device rule.

    Args:
      ctx: The rule context.

    Returns:
      A DefaultInfo provider.
    """

    # For now, only one bitstream. A target without deps has none of its
    # own, and its script takes one from --bitfile.
    bittarget = None
    for target in ctx.attr.deps:
        bittarget = target

    bitfile = None
    if bittarget != None:
        bitfile = bittarget[VivadoBitstreamProvider].bitstream
    bitfile_files = [bitfile] if bitfile != None else []

    # Needed binaries
    config = _vivado_config(ctx)
    script = config.runner.executable
    gotopt2 = ctx.attr._gotopt2.files.to_list()[0]
    generator = ctx.attr._proggen.files.to_list()[0]

    data = ctx.attr._data.files.to_list()

    # Select the template and flag config by name. The proggen:data filegroup
    # holds more than one template (main_script.tpl.sh for SRAM/bit programming
    # and flash_script.tpl.sh for flash), so positional indexing is unsafe --
    # adding a file to the filegroup shifts the positions and silently picks the
    # wrong template.
    tpl1 = None
    yaml = None
    bitfile_lib = None
    for f in data:
        if f.basename == "main_script.tpl.sh":
            tpl1 = f
        elif f.basename == "flags.yaml":
            yaml = f
        elif f.basename == "bitfile.bash":
            bitfile_lib = f
    if tpl1 == None or yaml == None or bitfile_lib == None:
        fail("vivado_program_device: could not find main_script.tpl.sh/flags.yaml/bitfile.bash in proggen data")

    for target in ctx.attr._tools:
        data += target.files.to_list()

    # Generated script file.
    daemon_inputs = []
    daemon_outputs = []
    default_runfiles = []

    outfile = ctx.actions.declare_file("{}.sh".format(ctx.attr.name))
    args = ctx.actions.args()
    args.add("--outfile", outfile.path)
    args.add("--gotopt2", gotopt2.path)
    args.add("--run-docker", script.path)
    args.add("--runner-rlocation", _rlocation_path(ctx, script))
    args.add("--template", tpl1.path)
    if bitfile != None:
        args.add("--bitfile", bitfile.short_path)
    else:
        args.add("--no-bitfile")
    args.add("--vivado-version", config.vivado_version)
    args.add("--vivado-path", config.vivado_path)
    args.add("--container", config.container)
    args.add("--vivado-mode", config.mode)

    # Add runner arguments here.
    prog_runner_args = ctx.expand_location(
        " ".join(ctx.attr.prog_daemon_args),
        targets = ctx.attr.data,
    )
    args.add("--prog-runner-args={}".format(prog_runner_args))
    args.add("--prog-runner-binary", ctx.files.prog_daemon[0].short_path)

    ctx.actions.run(
        inputs = [generator, gotopt2, script] + bitfile_files + daemon_outputs,
        outputs = [outfile],
        executable = generator,
        tools = [
            gotopt2,
            script,
        ] + data,
        arguments = [args],
        mnemonic = "PROGGEN",
        progress_message = "Generating programming script: {}".format(outfile.path),
    )

    runfiles = ctx.runfiles(
        files = [script, gotopt2, yaml, bitfile_lib] + bitfile_files,
        collect_data = True,
    )
    tools_files = []
    for target in ctx.attr._tools:
        tools_files += target.files.to_list()

    tools_runfiles = ctx.runfiles(files = tools_files, collect_data = True)

    default_runfiles += [
        config.runner_default_runfiles,
        ctx.attr._proggen[DefaultInfo].default_runfiles,
        ctx.attr._data[DefaultInfo].default_runfiles,
        ctx.attr._gotopt2[DefaultInfo].default_runfiles,
        ctx.attr.prog_daemon[DefaultInfo].default_runfiles,
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

vivado_program_device = rule(
    implementation = _vivado_program_device,
    executable = True,
    doc = """Loads a bitstream into the FPGA's volatile configuration memory.

`bazel run` the target. It connects to a hw_server and programs the
bitstream of the target in `deps`, unless `--bitfile` names another.

Flags:

- `--hostport`: the hw_server, often `localhost:3122`. Required.
- `--device`: the hardware target.
- `--bitfile`: a bitstream to program in place of the target's own, such
  as one that another session already built and checked. A relative path
  is relative to where `bazel run` was started. It is required when the
  target has no `deps`, which lets one target program bitstreams that
  were built elsewhere, without running place and route.
- `--sha256`: the SHA-256 that the bitstream must have, in hex. When the
  file's differs, the device is not programmed. It checks the `--bitfile`
  file when there is one, and the target's own bitstream otherwise.

The script refuses a file that does not start as a Xilinx `.bit` file
does, such as the placeholder that `vivado_place_and_route2` writes for a
failed `write_bitstream`.
""",
    toolchains = [VIVADO_TOOLCHAIN_TYPE],
    attrs = {
        "deps": attr.label_list(
            providers = [VivadoBitstreamProvider],
            doc = "The target whose bitstream to program. Without one, `--bitfile` is required when the target is run.",
        ),
        "_gotopt2": attr.label(
            default = "@gotopt2//:bin",
            executable = True,
            cfg = "host",
            doc = "The gotopt2 binary.",
        ),
        "_proggen": attr.label(
            default = Label("//build/vivado/bin/proggen"),
            executable = True,
            cfg = "host",
            doc = "The program to generate a programming wrapper",
        ),
        "_data": attr.label(
            default = Label("//build/vivado/bin/proggen:data"),
            doc = "The program to generate a programming wrapper",
            providers = [DefaultInfo],
        ),
        "prog_daemon": attr.label(
            doc = "The binary to start before programming",
            executable = True,
            cfg = "host",
        ),
        "prog_daemon_args": attr.string_list(
            doc = "The args to give to prog_daemon, subject to make var substitution",
        ),
        "data": attr.label_list(
            doc = "The list of dependencies to expand",
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
