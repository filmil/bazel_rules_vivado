"""Defines variables and functions used in Vivado rules."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_bid//build:rules.bzl", "run_docker_cmd")

DOCKER_RUN_SCRIPT_ATTRS = {
    "env": attr.string_dict(
        allow_empty = True,
        doc = "A dictionary of env variables to define for the run."
    ),
    "mount": attr.string_dict(
        allow_empty = True,
        doc = "A dictionary of mounts to define for the run."
    ),
    "_script": attr.label(
        default=Label("@rules_bid//build:docker_run"),
        executable=True,
        cfg="host",
        doc = "The script to run the docker container.",
    ),
}

DEFAULT_VIVADO_VERSION = "2025.1"
# This needs to exist on your computer before we begin.
DEFAULT_CONTAINER = "xilinx-vivado:{}".format(DEFAULT_VIVADO_VERSION)
# This is tied to the contents of the above CONTAINER.
DEFAULT_VIVADO_PATH = "/opt/Xilinx/{}/Vivado".format(DEFAULT_VIVADO_VERSION)

# Defaults re-exported as top-level constants so legacy call sites that do not
# yet go through `vivado_config(ctx)` keep compiling.
VIVADO_VERSION = DEFAULT_VIVADO_VERSION
CONTAINER = DEFAULT_CONTAINER
VIVADO_PATH = DEFAULT_VIVADO_PATH

# Attribute set that rules must merge into their `attrs` so that
# `vivado_config(ctx)` can read the user-supplied build setting flags.
VIVADO_CONFIG_ATTRS = {
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
}

def vivado_config(ctx):
    """Resolves the Vivado configuration from build setting flags.

    Falls back to DEFAULT_VIVADO_VERSION / DEFAULT_CONTAINER / DEFAULT_VIVADO_PATH
    when a flag is left at its empty default. When only `vivado_version` is set,
    the container image and Vivado install path are derived from it.

    Args:
      ctx: The rule context. The rule's `attrs` must include VIVADO_CONFIG_ATTRS.

    Returns:
      A struct with fields `vivado_version`, `container`, and `vivado_path`.
    """
    version = ctx.attr._vivado_version_flag[BuildSettingInfo].value or \
        DEFAULT_VIVADO_VERSION
    container = ctx.attr._vivado_container_flag[BuildSettingInfo].value or \
        "xilinx-vivado:{}".format(version)
    vivado_path = ctx.attr._vivado_path_flag[BuildSettingInfo].value or \
        "/opt/Xilinx/{}/Vivado".format(version)
    return struct(
        vivado_version = version,
        container = container,
        vivado_path = vivado_path,
    )

def script_cmd(
  script_path,
  dir_reference,
  cache_dir,
  source_dir="",
  mounts=None,
  envs=None,
  tools=None,
  freeargs=[],
  workdir_name="/work",
  container=None,
):
    """Generates the command line to run a docker container.

    Args:
      script_path: Path to the docker run script.
      dir_reference: Directory reference.
      cache_dir: Cache directory.
      source_dir: Source directory.
      mounts: Mounts to add.
      envs: Environment variables to add.
      tools: Tools to add.
      freeargs: Additional arguments to pass.
      workdir_name: The working directory name.
      container: Optional container image override. When None, the default
        CONTAINER is used. Pass `vivado_config(ctx).container` to honor
        user-supplied build setting flags.

    Returns:
      The generated command line as a string.
    """
    return run_docker_cmd(
        container or CONTAINER,
        script_path,
        dir_reference,
        scratch_dir="{}:/tmp/.cache".format(cache_dir),
        source_dir=source_dir,
        mounts=mounts,
        envs=envs,
        tools=tools,
        freeargs=freeargs,
        workdir_name="/work",
    )
