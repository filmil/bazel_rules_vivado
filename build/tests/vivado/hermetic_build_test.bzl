"""A build test that forces `--@rules_vivado//:vivado_mode=hermetic`.

This is the example of driving the hermetic (Bazel-installed) Vivado
toolchain from a regular target: a configuration transition pins the
`vivado_mode` flag to `hermetic` for everything below `targets`, so the
test exercises the hermetic toolchain no matter which mode the rest of
the build uses. Copy this file into your own workspace to do the same.

The rule passes when its `targets` build; the test executable itself only
checks that their outputs made it into the runfiles.
"""

def _hermetic_transition_impl(settings, attr):
    _ = (settings, attr)  # @unused
    return {"@rules_vivado//:vivado_mode": "hermetic"}

_hermetic_transition = transition(
    implementation = _hermetic_transition_impl,
    inputs = [],
    outputs = ["@rules_vivado//:vivado_mode"],
)

def _hermetic_build_test_impl(ctx):
    files = depset(transitive = [
        target[DefaultInfo].files
        for target in ctx.attr.targets
    ])
    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        script,
        "\n".join(
            ["#!/usr/bin/env bash", "set -e"] +
            ['test -e "{}"'.format(f.short_path) for f in files.to_list()] +
            ["echo PASS", ""],
        ),
        is_executable = True,
    )
    return [DefaultInfo(
        executable = script,
        runfiles = ctx.runfiles(transitive_files = files),
    )]

hermetic_build_test = rule(
    implementation = _hermetic_build_test_impl,
    test = True,
    doc = "Builds `targets` with the hermetic Vivado toolchain " +
          "(--@rules_vivado//:vivado_mode=hermetic), regardless of the " +
          "mode the invocation selected. Passes when they build.",
    attrs = {
        "targets": attr.label_list(
            mandatory = True,
            cfg = _hermetic_transition,
            doc = "Targets to build in hermetic mode.",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
