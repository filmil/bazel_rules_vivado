"""The Vivado execution toolchain.

The toolchain decides *how* Vivado tools are invoked: either inside the local
`xilinx-vivado:<version>` Docker container (the default), or directly on the
host, using a preexisting Vivado installation.

Selection happens through the `//:vivado_mode` build setting flag. Users pick
the host mode by adding this to their `.bazelrc`:

```
build --@rules_vivado//:vivado_mode=host
```

Both modes share a single command line format: rules generate a command that
starts with a "runner" executable. In docker mode the runner is
`@rules_bid//build:docker_run`, which wraps the command in `docker run`; in
host mode it is `//internal:host_run`, which accepts the same flags (ignoring
the docker-specific ones) and executes the command directly on the host.

Users with custom setups can define and register their own `vivado_toolchain`
instance instead of using the built-in ones in `//toolchains`.
"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

# The toolchain type label. Rules that invoke Vivado must declare
# `toolchains = [VIVADO_TOOLCHAIN_TYPE]` and use `vivado_config(ctx)` to
# obtain the resolved configuration.
VIVADO_TOOLCHAIN_TYPE = "//toolchains:toolchain_type"

DEFAULT_VIVADO_VERSION = "2025.2"

# This needs to exist on your computer before we begin.
DEFAULT_CONTAINER = "xilinx-vivado:{}".format(DEFAULT_VIVADO_VERSION)

# This is tied to the contents of the above CONTAINER. In host mode it is the
# path of the Vivado installation on the host filesystem instead.
DEFAULT_VIVADO_PATH = "/opt/Xilinx/{}/Vivado".format(DEFAULT_VIVADO_VERSION)

def _vivado_toolchain_impl(ctx):
    """Implementation for the vivado_toolchain rule.

    Resolution order for each configuration value: the build setting flag
    (`--//internal:vivado_*`) wins over the toolchain attribute, which wins
    over the built-in default. When only the version is known, the container
    image and Vivado install path are derived from it.

    Args:
      ctx: The rule context.

    Returns:
      A ToolchainInfo provider carrying the Vivado invocation configuration.
    """
    version = ctx.attr._vivado_version_flag[BuildSettingInfo].value or \
              ctx.attr.vivado_version or \
              DEFAULT_VIVADO_VERSION
    container = ctx.attr._vivado_container_flag[BuildSettingInfo].value or \
                ctx.attr.container or \
                "xilinx-vivado:{}".format(version)
    vivado_path = ctx.attr._vivado_path_flag[BuildSettingInfo].value or \
                  ctx.attr.vivado_path or \
                  "/opt/Xilinx/{}/Vivado".format(version)
    return [
        platform_common.ToolchainInfo(
            mode = ctx.attr.mode,
            vivado_version = version,
            container = container,
            vivado_path = vivado_path,
            runner = ctx.attr.runner[DefaultInfo].files_to_run,
            runner_default_runfiles = ctx.attr.runner[DefaultInfo].default_runfiles,
        ),
    ]

vivado_toolchain = rule(
    implementation = _vivado_toolchain_impl,
    doc = """Declares a Vivado execution toolchain.

The built-in instances live in `//toolchains`. Declare your own instance (and
register it with a `toolchain()` wrapper) to customize how Vivado is invoked,
e.g. to point at a nonstandard host installation:

```python
vivado_toolchain(
    name = "my_host_vivado",
    mode = "host",
    vivado_path = "/tools/Xilinx/Vivado/2024.2",
    vivado_version = "2024.2",
    runner = "@rules_vivado//internal:host_run",
)
```
""",
    attrs = {
        "mode": attr.string(
            mandatory = True,
            values = ["docker", "host"],
            doc = "How Vivado is executed: in the Docker container, or " +
                  "directly on the host.",
        ),
        "vivado_version": attr.string(
            doc = "The Vivado version. Empty means the built-in default, " +
                  "unless overridden by the --//internal:vivado_version flag.",
        ),
        "container": attr.string(
            doc = "The Vivado Docker image (docker mode only). Empty means " +
                  "derived from the version as `xilinx-vivado:<version>`, " +
                  "unless overridden by the --//internal:vivado_container flag.",
        ),
        "vivado_path": attr.string(
            doc = "The Vivado install path (inside the container in docker " +
                  "mode; on the host filesystem in host mode). Empty means " +
                  "derived from the version as `/opt/Xilinx/<version>/Vivado`, " +
                  "unless overridden by the --//internal:vivado_path flag.",
        ),
        "runner": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            doc = "The runner executable that command lines are prefixed " +
                  "with: `@rules_bid//build:docker_run` for docker mode, " +
                  "`//internal:host_run` for host mode. Both accept the " +
                  "same command line flags.",
        ),
        "_vivado_version_flag": attr.label(
            default = Label("//internal:vivado_version"),
            doc = "Build setting flag override for the Vivado version.",
        ),
        "_vivado_container_flag": attr.label(
            default = Label("//internal:vivado_container"),
            doc = "Build setting flag override for the Vivado Docker container image.",
        ),
        "_vivado_path_flag": attr.label(
            default = Label("//internal:vivado_path"),
            doc = "Build setting flag override for the Vivado install path.",
        ),
    },
)

def vivado_config(ctx):
    """Resolves the Vivado configuration from the Vivado toolchain.

    Args:
      ctx: The rule context. The rule must declare
        `toolchains = [VIVADO_TOOLCHAIN_TYPE]`.

    Returns:
      A struct with fields:
        mode: "docker" or "host".
        is_host: convenience bool, True in host mode.
        vivado_version: the Vivado version string.
        container: the Docker image (meaningful in docker mode only).
        vivado_path: the Vivado install path.
        runner: the runner executable, as a FilesToRunProvider. Pass it in
          `tools = [...]` of actions that run Vivado, and use
          `runner.executable.path` as the script path for `script_cmd`.
        runner_default_runfiles: the runner's default runfiles, for rules
          that place the runner into runfiles of generated scripts.
    """
    toolchain = ctx.toolchains[VIVADO_TOOLCHAIN_TYPE]
    return struct(
        mode = toolchain.mode,
        is_host = toolchain.mode == "host",
        vivado_version = toolchain.vivado_version,
        container = toolchain.container,
        vivado_path = toolchain.vivado_path,
        runner = toolchain.runner,
        runner_default_runfiles = toolchain.runner_default_runfiles,
    )

def rlocation_path(ctx, file):
    """Computes the runfiles (rlocation) path of a file.

    Args:
      ctx: The rule context.
      file: The file to compute the rlocation path for.

    Returns:
      The path suitable for lookup with `rlocation` in bash scripts.
    """
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    return ctx.workspace_name + "/" + file.short_path
