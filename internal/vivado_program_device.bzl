"""Vivado program device rule."""

load("//internal:providers.bzl",
    "VivadoBitstreamProvider",
)

def _vivado_program_device(ctx):
    """Implementation for the vivado_program_device rule.

    Args:
      ctx: The rule context.

    Returns:
      A DefaultInfo provider.
    """
    # For now, only one bitstream.
    bitstream = None
    bittarget = None
    for target in ctx.attr.deps:
        bittarget = target
        for file in target.files.to_list():
            bitstream = file
            break


    bitstream_provider = bittarget[VivadoBitstreamProvider]
    bitfile = bitstream_provider.bitstream

    # Needed binaries
    script = ctx.attr._script.files.to_list()[0]
    gotopt2 = ctx.attr._gotopt2.files.to_list()[0]
    generator = ctx.attr._proggen.files.to_list()[0]

    data = ctx.attr._data.files.to_list()
    for target in ctx.attr._tools:
        data += target.files.to_list()

    # These do not seem to be stable; why?
    tpl1 = data[1]
    yaml = data[0]


    # Generated script file.
    daemon_inputs = []
    daemon_outputs = []
    default_runfiles = []

    outfile = ctx.actions.declare_file("{}.sh".format(ctx.attr.name))
    args = ctx.actions.args()
    args.add("--outfile", outfile.path)
    args.add("--gotopt2", gotopt2.path)
    args.add("--run-docker", script.path)
    args.add("--template", tpl1.path)
    args.add("--bitfile", bitfile.short_path)

    # Add runner arguments here.
    prog_runner_args = ctx.expand_location(
        " ".join(ctx.attr.prog_daemon_args),
        targets=ctx.attr.data)
    args.add("--prog-runner-args={}".format(prog_runner_args))
    args.add("--prog-runner-binary", ctx.files.prog_daemon[0].short_path)

    ctx.actions.run(
        inputs = [generator, gotopt2, script, bitfile] + daemon_outputs,
        outputs = [outfile],
        executable = generator,
        tools = [
            gotopt2, script
        ] + data,
        arguments = [args],
        mnemonic = "PROGGEN",
        progress_message = "Generating programming script: {}".format(outfile.path),
    )

    runfiles = ctx.runfiles(
        files=[script, gotopt2, yaml, bitfile],
        collect_data = True,
    )
    tools_files = []
    for target in ctx.attr._tools:
        tools_files += target.files.to_list()

    tools_runfiles = ctx.runfiles(files=tools_files, collect_data=True)

    default_runfiles += [
        ctx.attr._script[DefaultInfo].default_runfiles,
        ctx.attr._proggen[DefaultInfo].default_runfiles,
        ctx.attr._data[DefaultInfo].default_runfiles,
        ctx.attr._gotopt2[DefaultInfo].default_runfiles,
        ctx.attr.prog_daemon[DefaultInfo].default_runfiles,
        tools_runfiles,
    ]

    runfiles = runfiles.merge_all(default_runfiles)

    return [
        DefaultInfo(
            files=depset([outfile, yaml, gotopt2]),
            runfiles=runfiles,
            executable = outfile,
        )
    ]

vivado_program_device = rule(
    implementation = _vivado_program_device,
    executable = True,
    attrs = {
        "deps": attr.label_list(
            providers = [VivadoBitstreamProvider],
            doc = "The list of deps containing bitstream code",
        ),
        "_script": attr.label(
            default="@rules_bid//build:docker_run",
            executable=True,
            cfg="host",
            doc = "The docker run script.",
        ),
        "_gotopt2": attr.label(
            default="@gotopt2//:bin",
            executable=True,
            cfg="host",
            doc = "The gotopt2 binary.",
        ),
        "_proggen": attr.label(
            default=Label("//build/vivado/bin/proggen"),
            executable=True,
            cfg="host",
            doc = "The program to generate a programming wrapper",
        ),
        "_data": attr.label(
            default=Label("//build/vivado/bin/proggen:data"),
            doc = "The program to generate a programming wrapper",
            providers = ["files"],
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
