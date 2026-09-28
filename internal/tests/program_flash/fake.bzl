"""A bitstream that is any file, so a flash target can be analysed and
its TCL written without a synthesis behind it."""

load("//internal:providers.bzl", "VivadoBitstreamProvider")

def _fake_bitstream_impl(ctx):
    return [
        DefaultInfo(files = depset([ctx.file.bit])),
        VivadoBitstreamProvider(bitstream = ctx.file.bit, probes = None),
    ]

fake_bitstream = rule(
    implementation = _fake_bitstream_impl,
    attrs = {"bit": attr.label(allow_single_file = True, mandatory = True)},
)
