"""Rule to program a bitstream into a device's non-volatile flash.

The `vivado_program_device` rule loads a bitstream into the FPGA's volatile
configuration SRAM, which is lost on the next power cycle. `vivado_program_flash`
instead writes the design into the board's non-volatile SPI/QSPI configuration
flash so that the FPGA loads the design automatically at power-up -- i.e. it
programs the device "permanently".

It works in two phases:

1. A hermetic build action runs Vivado's `write_cfgmem` to convert the `.bit`
   into a flash image (`.mcs`/`.bin`) for the configured flash part. This needs
   Vivado but no hardware, so it is a normal, cacheable Bazel build action --
   `bazel build` on the target produces the flash image.
2. A generated `bazel run` wrapper connects to a running hardware server and
   erases + writes that image into the device flash via Vivado's
   `create_hw_cfgmem` / `program_hw_cfgmem`. This needs the physical board.
"""

load("//internal:providers.bzl",
    "VivadoBitstreamProvider",
)
load("//internal:defines.bzl",
    "VIVADO_CONFIG_ATTRS",
    _script_cmd = "script_cmd",
    _vivado_config = "vivado_config",
)

def _vivado_program_flash_impl(ctx):
    """Implementation for the vivado_program_flash rule.

    Args:
      ctx: The rule context.

    Returns:
      A list of providers with DefaultInfo carrying the flash image and the
      executable programming wrapper.
    """
    if not ctx.attr.deps:
        fail("vivado_program_flash: `deps` must contain exactly one target " +
             "providing VivadoBitstreamProvider.")

    config = _vivado_config(ctx)
    docker_run = ctx.executable._script
    bitfile = ctx.attr.deps[0][VivadoBitstreamProvider].bitstream

    # --- Phase 1: build the flash image with write_cfgmem (no hardware). ---
    mcs = ctx.actions.declare_file("{}.{}".format(ctx.attr.name, ctx.attr.format))
    cache_dir = ctx.actions.declare_directory(
        "_vivado_program_flash.cache.{}".format(ctx.label.name),
    )

    # write_cfgmem runs inside the container whose working directory is the exec
    # root, so exec-root-relative paths (bitfile.path, mcs.path) resolve. The
    # TCL braces around `up 0x0 <bit>` are required by write_cfgmem.
    cfgmem_tcl = ctx.actions.declare_file("{}.cfgmem.tcl".format(ctx.attr.name))
    ctx.actions.write(
        output = cfgmem_tcl,
        content = (
            "write_cfgmem -force -format {fmt} -size {size} -interface {iface}" +
            " -loadbit {{up 0x0 {bit}}} -file {mcs}\n"
        ).format(
            fmt = ctx.attr.format,
            size = ctx.attr.size,
            iface = ctx.attr.interface,
            bit = bitfile.path,
            mcs = mcs.path,
        ),
    )

    script = _script_cmd(
        docker_run.path,
        mcs.path,
        cache_dir.path,
        freeargs = ["--net=host", "-e", "HOME=/work"],
        container = config.container,
    )

    ctx.actions.run_shell(
        progress_message = "Vivado write_cfgmem \"{}\" ({} {})".format(
            ctx.attr.name,
            ctx.attr.format,
            ctx.attr.flash_part,
        ),
        inputs = [docker_run, cfgmem_tcl, bitfile],
        outputs = [mcs, cache_dir],
        tools = [docker_run],
        mnemonic = "VivadoCfgmem",
        command = (
            "mkdir -p \"$(dirname {mcs})\" && " +
            "{script} " +
            "LD_LIBRARY_PATH=\"{vivado_path}/lib/lnx64.o\" " +
            "{vivado_path}/bin/setEnvAndRunCmd.sh vivado " +
            "-notrace -mode batch -source {tcl} 1>&2"
        ).format(
            mcs = mcs.path,
            script = script,
            vivado_path = config.vivado_path,
            tcl = cfgmem_tcl.path,
        ),
    )

    # --- Phase 2: generate the bazel-run flash programming wrapper. ---
    gotopt2 = ctx.attr._gotopt2.files.to_list()[0]
    generator = ctx.attr._proggen.files.to_list()[0]

    data = ctx.attr._data.files.to_list()
    yaml = None
    template = None
    for f in data:
        if f.basename == "flags.yaml":
            yaml = f
        elif f.basename == "flash_script.tpl.sh":
            template = f
    if yaml == None or template == None:
        fail("vivado_program_flash: could not find flags.yaml/flash_script.tpl.sh in proggen data")

    outfile = ctx.actions.declare_file("{}.sh".format(ctx.attr.name))
    args = ctx.actions.args()
    args.add("--outfile", outfile.path)
    args.add("--gotopt2", gotopt2.path)
    args.add("--run-docker", docker_run.path)
    args.add("--template", template.path)
    args.add("--mcs-file", mcs.short_path)
    args.add("--flash-part", ctx.attr.flash_part)
    args.add("--flash-interface", ctx.attr.interface)
    args.add("--vivado-version", config.vivado_version)

    if ctx.attr.prog_daemon:
        prog_runner_args = ctx.expand_location(
            " ".join(ctx.attr.prog_daemon_args),
            targets = ctx.attr.data,
        )
        args.add("--prog-runner-args={}".format(prog_runner_args))
        args.add("--prog-runner-binary", ctx.files.prog_daemon[0].short_path)

    ctx.actions.run(
        inputs = [generator, gotopt2, docker_run, mcs],
        outputs = [outfile],
        executable = generator,
        tools = [gotopt2, docker_run] + data,
        arguments = [args],
        mnemonic = "FLASHGEN",
        progress_message = "Generating flash programming script: {}".format(outfile.path),
    )

    # --- Runfiles for the generated wrapper. ---
    runfiles = ctx.runfiles(
        files = [docker_run, gotopt2, yaml, mcs],
        collect_data = True,
    )
    tools_files = []
    for target in ctx.attr._tools:
        tools_files += target.files.to_list()
    tools_runfiles = ctx.runfiles(files = tools_files, collect_data = True)

    default_runfiles = [
        ctx.attr._script[DefaultInfo].default_runfiles,
        ctx.attr._proggen[DefaultInfo].default_runfiles,
        ctx.attr._data[DefaultInfo].default_runfiles,
        ctx.attr._gotopt2[DefaultInfo].default_runfiles,
        tools_runfiles,
    ]
    if ctx.attr.prog_daemon:
        default_runfiles.append(ctx.attr.prog_daemon[DefaultInfo].default_runfiles)

    runfiles = runfiles.merge_all(default_runfiles)

    return [
        DefaultInfo(
            files = depset([mcs, outfile, yaml, gotopt2]),
            runfiles = runfiles,
            executable = outfile,
        ),
    ]

vivado_program_flash = rule(
    implementation = _vivado_program_flash_impl,
    executable = True,
    doc = "Programs a bitstream into a device's non-volatile configuration " +
          "flash (SPI/QSPI) so it loads automatically on power-up. " +
          "`bazel build` produces the flash image (.mcs/.bin); `bazel run` " +
          "writes it to the board (requires --hostport and --device).",
    attrs = VIVADO_CONFIG_ATTRS | {
        "deps": attr.label_list(
            providers = [VivadoBitstreamProvider],
            doc = "Exactly one target providing the bitstream to flash.",
        ),
        "flash_part": attr.string(
            mandatory = True,
            doc = "The Vivado cfgmem part name of the target flash device, " +
                  "e.g. 'mt25ql256-spi-x1_x2_x4'. Board-specific; see " +
                  "`get_cfgmem_parts` in Vivado.",
        ),
        "size": attr.int(
            mandatory = True,
            doc = "The flash capacity in megabytes (MB), passed to " +
                  "`write_cfgmem -size`.",
        ),
        "interface": attr.string(
            default = "SPIx4",
            doc = "The flash programming interface, e.g. SPIx1/SPIx2/SPIx4.",
        ),
        "format": attr.string(
            default = "mcs",
            values = ["mcs", "bin"],
            doc = "The flash image format produced by `write_cfgmem`.",
        ),
        "prog_daemon": attr.label(
            doc = "Optional binary to start before programming (e.g. a " +
                  "hardware server).",
            executable = True,
            cfg = "host",
        ),
        "prog_daemon_args": attr.string_list(
            doc = "Args for prog_daemon, subject to make var substitution.",
        ),
        "data": attr.label_list(
            doc = "The list of dependencies to expand in prog_daemon_args.",
        ),
        "_script": attr.label(
            default = "@rules_bid//build:docker_run",
            executable = True,
            cfg = "host",
            doc = "The docker run script.",
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
            doc = "The program that generates the programming wrapper.",
        ),
        "_data": attr.label(
            default = Label("//build/vivado/bin/proggen:data"),
            doc = "The proggen templates and flag configuration.",
            providers = [DefaultInfo],
        ),
        "_tools": attr.label_list(
            default = [
                Label("@bazel_tools//tools/bash/runfiles"),
                Label("@fshlib//:log"),
            ],
            doc = "Runtime helper dependencies.",
        ),
    },
)
