"""A rule outside rules_vivado that runs under the Vivado toolchain.

It uses only the public `@rules_vivado//build/vivado:rules.bzl`, as any
other repository would, and checks that `vivado_config(ctx)` resolves.
"""

load("@rules_vivado//build/vivado:rules.bzl", "VIVADO_TOOLCHAIN_TYPE", "vivado_config")

def _vivado_config_test_impl(ctx):
    config = vivado_config(ctx)
    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = script,
        is_executable = True,
        content = """#!/bin/sh
set -e
echo "mode={mode} is_host={is_host} vivado_path={vivado_path} runner={runner}"
case '{mode}' in docker|host) ;; *) echo "unexpected mode" >&2; exit 1 ;; esac
test '{is_host}' = '{want_host}'
test -n '{vivado_path}'
test -n '{runner}'
""".format(
            mode = config.mode,
            is_host = config.is_host,
            want_host = config.mode == "host",
            vivado_path = config.vivado_path,
            runner = config.runner.executable.path,
        ),
    )
    return [DefaultInfo(executable = script)]

vivado_config_test = rule(
    implementation = _vivado_config_test_impl,
    test = True,
    toolchains = [VIVADO_TOOLCHAIN_TYPE],
)
