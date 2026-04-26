"""Vivado place and route rule."""

load("//internal:defines.bzl",
    "VIVADO_VERSION", "CONTAINER", "VIVADO_PATH",
    _script_cmd = "script_cmd",
)
load("//internal:providers.bzl",
    "VivadoGenProvider",
    "VivadoSynthProvider",
    "VivadoBitstreamProvider",
)

def _vivado_pnr_impl(ctx):
  """Implementation for the vivado_place_and_route rule.

  Args:
    ctx: The rule context.

  Returns:
    A list of providers, including DefaultInfo and VivadoBitstreamProvider.
  """
  name = ctx.attr.name
  project = ctx.attr.synthesis
  provider = project[VivadoGenProvider]
  synth_provider = project[VivadoSynthProvider]
  project_name = provider.project_name

  # See above for these settings.
  docker_run = ctx.executable._script
  env = ctx.attr.env
  mounts = {}
  if ctx.attr.mount:
    mounts.update(ctx.attr.mount)
  mounts.update({
    "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
  })

  # Output dirs from the prior step must be reused.
  synth_output_dir = synth_provider.synth_output_dir
  xpr_file = synth_provider.synth_xpr_file
  inputs = [provider.pnr_tcl_script, xpr_file, synth_output_dir]

  # Process xdcs
  xdcs_files = [f for f in provider.constraints.to_list()]
  inputs += xdcs_files
  xdcs_paths = [ f.path for f in xdcs_files ]
  inputs += xdcs_files

  # Process sources
  inputs += [file for file in provider.sources.to_list()]

  # Outputs
  # Since Vivado very generously creates directories willy-nilly, we have to
  # collect a bunch of them here so that they would be passed along to the
  # next steps in the pipeline.
  output_dir_path = "_pnr.work.{}".format(name)
  output_dir = ctx.actions.declare_directory(output_dir_path)
  outputs = [output_dir]

  synth_tcl_script = provider.synth_tcl_script
  inputs += [synth_tcl_script]

  cache_dir_rpath = "_pnr.cache.{}".format(project_name)
  cache_dir = ctx.actions.declare_directory(cache_dir_rpath)
  outputs += [cache_dir]

  bit_file = ctx.actions.declare_file("{}.bit".format(project_name))
  outputs += [bit_file]

  script = _script_cmd(
    docker_run.path,
    output_dir.path,
    cache_dir.path,
    envs=",".join(["{}={}".format(k, v) for (k,v) in env.items()]),
    mounts=",".join(["{}:{}".format(k, v) for (k,v) in mounts.items()]),
    freeargs=[
      "--net=host",
      "-e", "HOME=/work",
    ],
  )

  # Run vivado with the script in the container
  # The copy/chmod shenanigans are needed to work around Vivado's hostile
  # attitude towards sandboxing.
  ctx.actions.run_shell(
    progress_message = "Vivado Place and Route \"{}\"".format(name),
    inputs = inputs + [docker_run],
    outputs = outputs,
    mnemonic = "VPNR",
    tools = [docker_run],
    command = """\
      echo "BAZEL: Vivado working directory is: $PWD" && \
      echo "BAZEL: Vivado output directory is : {vivado_workdir}" && \
      echo "BAZEL: XPR: {xpr_src}-> {project_name}.xpr" && \
      cp -R -a --dereference {synth_output_dir_path}/* "$PWD" && \
      mkdir -p {project_name}.ip_user_files && \
      mkdir -p {project_name}.gen/sources_1 && \
      cp --dereference {xpr_src} {project_name}.xpr && \
      chmod --recursive a+w {project_name}.xpr \
        {project_name}.runs {project_name}.gen && \
      {script} \
      LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
      {vivado_path}/bin/setEnvAndRunCmd.sh vivado \
        -notrace -mode batch -source {pnr_tcl} {project_name}.xpr && \
      cp -R --dereference {project_name}.gen {vivado_workdir} && \
      cp -R --dereference {project_name}.hw {vivado_workdir} && \
      cp -R --dereference {project_name}.ip_user_files {vivado_workdir} && \
      cp -R --dereference {project_name}.runs {vivado_workdir} && \
      cp --dereference {bit_file_rpath} {bit_file} && \
      echo BAZEL: Done \
    """.format(
      bit_file = bit_file.path,
      bit_file_rpath = bit_file.basename,
      # test.xpr
      xpr_file = xpr_file.basename,
      xpr_src = xpr_file.path,
      pnr_tcl = provider.pnr_tcl_script.path,

      # tools
      vivado_path = VIVADO_PATH,
      vivado_workdir = output_dir.path,
      script = script,
      synth_tcl = synth_tcl_script.path,
      cache_dir = cache_dir.path,

      # From synth
      synth_output_dir_path = synth_output_dir.path,

      project_name = project_name,
    )
  )

  return [
    DefaultInfo(
      files = depset(outputs),
      runfiles = ctx.runfiles(files = outputs),
    ),
    VivadoBitstreamProvider(bitstream = bit_file),
  ]

vivado_place_and_route = rule(
    implementation = _vivado_pnr_impl,
    attrs = {
        "synthesis": attr.label(
            doc = "The vivado synthesis to place and route",
            mandatory = True,
            providers = [VivadoGenProvider, VivadoSynthProvider],
        ),
        "env": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of env variables to define for the run."
        ),
        "mount": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of mounts to define for the run."
        ),
        "_script": attr.label(
            default="@rules_bid//build:docker_run",
            executable=True,
            cfg="host",
            doc = "The docker run script.",
        ),
    },
)
