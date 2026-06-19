"""Vivado read ILA rule."""

load("//internal:providers.bzl",
    "VivadoBitstreamProvider",
)
load("//internal:defines.bzl",
    "VIVADO_CONFIG_ATTRS",
    _vivado_config = "vivado_config",
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
    script = ctx.attr._script.files.to_list()[0]
    gotopt2 = ctx.attr._gotopt2.files.to_list()[0]
    generator = ctx.attr._ilagen.files.to_list()[0]

    data = ctx.attr._data.files.to_list()
    for target in ctx.attr._tools:
        data += target.files.to_list()

    tpl1 = data[1]
    yaml = data[0]

    # Generated script file.
    default_runfiles = []

    config = _vivado_config(ctx)

    outfile = ctx.actions.declare_file("{}.sh".format(ctx.attr.name))
    args = ctx.actions.args()
    args.add("--outfile", outfile.path)
    args.add("--gotopt2", gotopt2.path)
    args.add("--run-docker", script.path)
    args.add("--template", tpl1.path)
    args.add("--ltxfile", probes_file.short_path)
    args.add("--vivado-version", config.vivado_version)

    ctx.actions.run(
        inputs = [generator, gotopt2, script, probes_file],
        outputs = [outfile],
        executable = generator,
        tools = [
            gotopt2, script
        ] + data,
        arguments = [args],
        mnemonic = "ILAGEN",
        progress_message = "Generating ILA read script: {}".format(outfile.path),
    )

    runfiles = ctx.runfiles(
        files=[script, gotopt2, yaml, probes_file],
        collect_data = True,
    )
    tools_files = []
    for target in ctx.attr._tools:
        tools_files += target.files.to_list()

    tools_runfiles = ctx.runfiles(files=tools_files, collect_data=True)

    default_runfiles += [
        ctx.attr._script[DefaultInfo].default_runfiles,
        ctx.attr._ilagen[DefaultInfo].default_runfiles,
        ctx.attr._data[DefaultInfo].default_runfiles,
        ctx.attr._gotopt2[DefaultInfo].default_runfiles,
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

vivado_read_ila = rule(
    implementation = _vivado_read_ila,
    executable = True,
    attrs = VIVADO_CONFIG_ATTRS | {
        "deps": attr.label_list(
            providers = [VivadoBitstreamProvider],
            doc = "The list of deps containing bitstream/probes code",
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
        "_ilagen": attr.label(
            default=Label("//build/vivado/bin/ilagen"),
            executable=True,
            cfg="host",
            doc = "The program to generate an ILA read wrapper",
        ),
        "_data": attr.label(
            default=Label("//build/vivado/bin/ilagen:data"),
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
