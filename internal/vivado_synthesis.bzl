"""Vivado synthesis rule."""

load("//internal:defines.bzl",
    "VIVADO_VERSION", "CONTAINER", "VIVADO_PATH",
    _script_cmd = "script_cmd",
    "DOCKER_RUN_SCRIPT_ATTRS",
)
load("//internal:providers.bzl",
    "VivadoGenProvider",
    "VivadoSynthProvider",
)

def _vivado_synthesis_impl(ctx):
  """Implementation for the vivado_synthesis rule.

  Args:
    ctx: The rule context.

  Returns:
    A list of providers, including DefaultInfo, VivadoGenProvider, and VivadoSynthProvider.
  """
  # Rule name. Must be unique.
  name = ctx.attr.name
  project = ctx.attr.project
  provider = ctx.attr.project[VivadoGenProvider]
  # Project name is the name of the rule that generated the project.
  project_name = provider.project_name

  docker_run = ctx.executable._script
  env = ctx.attr.env
  mounts = {}
  if ctx.attr.mount:
    mounts.update(ctx.attr.mount)
  mounts.update({
    "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
  })

  xpr_gen_output_dir = provider.xpr_gen_output_dir
  inputs = [provider.synth_tcl_script, xpr_gen_output_dir]


  synth_tcl_script = provider.synth_tcl_script
  inputs += [synth_tcl_script]
  # Process srcs
  srcs_files = [f for f in provider.sources.to_list()]
  inputs += srcs_files
  src_paths = [ f.path for f in srcs_files ]
  # Process hdrs
  hdrs_files = [f for f in provider.headers.to_list()]
  inputs += hdrs_files
  hdrs_paths = [ f.path for f in hdrs_files ]
  # Process xdcs
  xdcs_files = [f for f in provider.constraints.to_list()]
  inputs += xdcs_files
  xdcs_paths = [ f.path for f in xdcs_files ]

  # Prepare include dirs
  include_dirs = provider.include_dirs  # list(string)

  xpr_file_base = provider.xpr_file.basename
  inputs += [provider.xpr_file]

  # Outputs
  # Since Vivado very generously creates directories willy-nilly, we have to
  # collect a bunch of them here so that they would be passed along to the
  # next steps in the pipeline.
  output_dir_path = "_synthesis.work.{}".format(name)
  output_dir = ctx.actions.declare_directory(output_dir_path)
  outputs = [output_dir]

  cache_dir_rpath = "_synthesis.cache.{}".format(project_name)
  cache_dir = ctx.actions.declare_directory(cache_dir_rpath)
  outputs += [cache_dir]

  # The zoo of generated directories.
  runs_dir_rpath = "{}.runs".format(project_name)
  ip_user_files_dir_rpath = "{}.ip_user_files".format(project_name)
  test_gen_rpath = "{}.gen".format(project_name)
  test_hw_rpath = "{}.hw".format(project_name)

  output_xpr_file = ctx.actions.declare_file("{}.xpr".format(name))
  outputs += [output_xpr_file]

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
    progress_message = "Vivado Synthesis \"{}\"".format(name),
    inputs = inputs + [docker_run],
    outputs = outputs,
    mnemonic = "VSYN",
    tools = [docker_run],
    command = """\
      echo "BAZEL: Vivado synthesis" && \
      echo "BAZEL: Vivado working directory is: $PWD" && \
      echo "BAZEL: Vivado output directory is : {output_dir_path}" && \
      mkdir -p {output_dir_path} && \
      cp --dereference {xpr_src} {xpr_file} && \
      chmod a+w {xpr_file} && \
      cp -R --dereference {xpr_gen_output_dir} $PWD && \
      TCL_FILES="$(find . -name '*.tcl')" && \
         if [[ "$TCL_FILES" != "" ]]; then \
            cp -R --dereference $TCL_FILES {output_dir_path} ; \
         fi && \
      VHDL_FILES="$(find . -name '*.vhd?')" && \
         if [[ "$VHDL_FILES" != "" ]]; then \
            cp -R --dereference $VHDL_FILES {output_dir_path} ; \
         fi && \
      V_FILES="$(find . -name '*.v')" && \
         if [[ "$V_FILES" != "" ]]; then \
            cp -R --dereference $V_FILES {output_dir_path} ; \
         fi && \
      SV_FILES="$(find . -name '*.sv')" && \
         if [[ "$SV_FILES" != "" ]]; then \
            cp -R --dereference $SV_FILES {output_dir_path} ; \
         fi && \
      mkdir -p {user_files_dir} && \
      mkdir -p {test_gen_dir}/sources_1 && \
      {script} \
      LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
      {vivado_path}/bin/setEnvAndRunCmd.sh vivado \
        -notrace -mode batch -source {synth_tcl} {xpr_file} 1>&2 && \
      cp -R --dereference {runs_dir_rpath} {output_dir_path} && \
      cp -R --dereference {test_hw_rpath} {output_dir_path} && \
      cp -R --dereference {user_files_dir} {output_dir_path} && \
      cp -R --dereference {test_gen_dir} {output_dir_path} && \
      cp --dereference {xpr_file} {output_xpr_file} && \
      rm -f {xpr_file} && \
      echo BAZEL: Done \
    """.format(
      # Copy the results from the generator step.
      output_dir_path = output_dir.path,
      xpr_gen_output_dir = xpr_gen_output_dir.path,

      runs_dir_rpath = runs_dir_rpath,
      test_gen_dir = test_gen_rpath,
      test_hw_rpath = test_hw_rpath,
      xpr_file = xpr_file_base,
      output_xpr_file = output_xpr_file.path,

      xpr_src = provider.xpr_file.path,

      # tools
      vivado_path = VIVADO_PATH,
      user_files_dir = ip_user_files_dir_rpath,
      script = script,
      synth_tcl = synth_tcl_script.path,

      project_name = provider.project_name,
    )
  )

  return [
    DefaultInfo(
      files = depset(outputs),
      runfiles = ctx.runfiles(files = outputs),
    ),
    provider,
    VivadoSynthProvider(
      synth_output_dir = output_dir,
      synth_xpr_file = output_xpr_file,
    ),
  ]

vivado_synthesis = rule(
    implementation = _vivado_synthesis_impl,
    attrs = DOCKER_RUN_SCRIPT_ATTRS | {
        "project": attr.label(
            doc = "The Vivado project to work on",
            mandatory = True,
            providers = [VivadoGenProvider],
        ),
    },
)
