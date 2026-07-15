"""Defines variables and functions used in Vivado rules."""

load("@rules_bid//build:rules.bzl", "run_docker_cmd")
load(
    "//internal:toolchain.bzl",
    _DEFAULT_CONTAINER = "DEFAULT_CONTAINER",
    _DEFAULT_VIVADO_PATH = "DEFAULT_VIVADO_PATH",
    _DEFAULT_VIVADO_VERSION = "DEFAULT_VIVADO_VERSION",
    _VIVADO_TOOLCHAIN_TYPE = "VIVADO_TOOLCHAIN_TYPE",
    _rlocation_path = "rlocation_path",
    _vivado_config = "vivado_config",
)

# Re-exports from //internal:toolchain.bzl, so that rules only need to load
# //internal:defines.bzl.
VIVADO_TOOLCHAIN_TYPE = _VIVADO_TOOLCHAIN_TYPE
vivado_config = _vivado_config
rlocation_path = _rlocation_path

DEFAULT_VIVADO_VERSION = _DEFAULT_VIVADO_VERSION
DEFAULT_CONTAINER = _DEFAULT_CONTAINER
DEFAULT_VIVADO_PATH = _DEFAULT_VIVADO_PATH

DOCKER_RUN_SCRIPT_ATTRS = {
    "env": attr.string_dict(
        allow_empty = True,
        doc = "A dictionary of env variables to define for the run.",
    ),
    "mount": attr.string_dict(
        allow_empty = True,
        doc = "A dictionary of mounts to define for the run.",
    ),
}

# Defaults re-exported as top-level constants so legacy call sites that do not
# yet go through `vivado_config(ctx)` keep compiling.
VIVADO_VERSION = DEFAULT_VIVADO_VERSION
CONTAINER = DEFAULT_CONTAINER
VIVADO_PATH = DEFAULT_VIVADO_PATH

# Deprecated: rules now obtain their Vivado configuration from the Vivado
# toolchain (see //internal:toolchain.bzl) instead of per-rule flag
# attributes. Kept as an empty attribute set for compatibility with call
# sites that still merge it into their `attrs`.
VIVADO_CONFIG_ATTRS = {}

def script_cmd(
        script_path,
        dir_reference,
        cache_dir,
        source_dir = "",
        mounts = None,
        envs = None,
        tools = None,
        freeargs = [],
        workdir_name = "/work",
        container = None):
    """Generates the command line to run a Vivado command through a runner.

    The generated command line starts with the runner script at `script_path`
    and works with both runners the Vivado toolchain can supply: the docker
    runner (`@rules_bid//build:docker_run`) consumes all flags and executes
    the command inside the container, while the host runner
    (`//internal:host_run`) ignores the docker-specific flags and executes
    the command directly on the host. Pass
    `vivado_config(ctx).runner.executable.path` as `script_path` to honor the
    toolchain selection.

    Args:
      script_path: Path to the runner script (docker_run or host_run).
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
        "$(pwd)/" + dir_reference,
        scratch_dir = "$(pwd)/{}:/tmp/.cache".format(cache_dir),
        source_dir = source_dir,
        mounts = mounts,
        envs = envs,
        tools = tools,
        freeargs = freeargs,
        workdir_name = "/work",
    )
