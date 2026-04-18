"""Defines variables and functions used in Vivado rules."""

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

VIVADO_VERSION = "2025.1"
# This needs to exist on your computer before we begin.
CONTAINER = "xilinx-vivado:{}".format(VIVADO_VERSION)
# This is tied to the contents of the above CONTAINER.
VIVADO_PATH = "/opt/Xilinx/{}/Vivado".format(VIVADO_VERSION)

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

    Returns:
      The generated command line as a string.
    """
    return run_docker_cmd(
        CONTAINER,
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
