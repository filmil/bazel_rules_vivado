load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_rules_bid//build:rules.bzl", "run_docker_cmd")

VivadoGenProvider = provider(
  "Infromation about generated vivado files",
  fields = {
    "sources": "The list of the module's source files",
    "headers": "A list of header files. " +
      " Headers are present in the sandbox, but not on the command line",
    "constraints": "The list of constraints files to use",
    "include_dirs": "A list of include directories for the code at hand",
    "xpr_tcl_script": "The TCL script used by vivado to generate a project file",
    "synth_tcl_script": "The TCL script used to start synthesis",
    "pnr_tcl_script": "The TCL script used to start place and route",
    "pgm_tcl_script": "The TCL script used to start programming the device",
    "xpr_file": "The generated Vivado project file",
    "top_level": "The top level entity to process",
    "project_name": "The name of the project, after the target",
    "xpr_gen_output_dir": "The output directory from the xpr_gen step",
    "part": "The part designator that is being targeted in this project",
  },
)

VivadoSynthProvider = provider(
  "Information about the synthesis step",
  fields = {
    "synth_output_dir": "",
    # It seems that Vivado wants to write into it.
    "synth_xpr_file": "The XPR file after synthesis",
  },
)

# This needs to exist on your computer before we begin.
CONTAINER = "xilinx-vivado:latest"

# This is tied to the contents of the above CONTAINER.
VIVADO_PATH = "/opt/Xilinx/Vivado/2023.2"


def _script_cmd(
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
    return run_docker_cmd(
        CONTAINER,
        script_path,
        dir_reference,
        scratch_dir="{}:/.cache".format(cache_dir),
        source_dir=source_dir,
        mounts=mounts,
        envs=envs,
        tools=tools,
        freeargs=freeargs,
        workdir_name="/work",
    )


def _xpr_gen(
  ctx,
  srcs_files,
  hdrs_files,
  xdcs_files,
  include_dirs,
  xpr_tcl_script,
):
  # General
  name = ctx.attr.name
  docker_run = ctx.executable._script
  env = ctx.attr.env
  mounts = {}
  if ctx.attr.mount:
    mounts.update(ctx.attr.mount)
  mounts.update({
    "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
  })

  # Outputs
  output_dir_path = "_xpr_gen.work.{}".format(name)
  output_dir = ctx.actions.declare_directory(output_dir_path)
  outputs = [output_dir]

  cache_dir = ctx.actions.declare_directory(
    "_xpr_gen.cache.{}".format(ctx.label.name))
  outputs += [cache_dir]

  script = _script_cmd(
    docker_run.path,
    output_dir.path,
    cache_dir.path,
    envs=",".join(["{}={}".format(k, v) for (k,v) in env.items()]),
    mounts=",".join(["{}:{}".format(k, v) for (k,v) in mounts.items()]),
    freeargs=[
      "--net=host",
      "-e", "HOME=/work",
      "-w", "/work",
    ],
  )


  project_file = ctx.actions.declare_file("{}.xpr".format(name))
  outputs += [project_file]
  tmp_project_file_path = "{}.xpr".format(name)
  inputs = xdcs_files + srcs_files + hdrs_files + [xpr_tcl_script]

  # Here is a zoo of directories that vivado creates and we need to preserve
  cache_dir_rpath = "{}.cache".format(name)
  hw_dir_rpath = "{}.hw".format(name)
  ip_user_files_dir_rpath = "{}.ip_user_files".format(name)
  jou_file_rpath = "vivado.jou"
  log_file_rpath = "vivado.log"

  # Vivado places the XPR file in the current working directory, and that can
  # not be changed.  So we do a dirty trick, and copy the resulting file from
  # the "current" working directory into its intended destination. This must
  # be done as part of the same command, else it will be impossible to
  # excavate the file from the sandbox that ran this command.
  ctx.actions.run_shell(
    progress_message = "Vivado XPR gen \"{}\"".format(name),
    inputs = inputs + [docker_run],
    outputs = outputs,
    mnemonic = "VivadoXPR",
    tools = [docker_run],
    command = """\
      echo "BAZEL: Vivado XPR generate" && \
      {script} \
      LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
      {vivado_path}/bin/setEnvAndRunCmd.sh vivado \
        -notrace -mode batch -source {xpr_tcl} && \
      cp --dereference {xprsrc} {xprdest} && \
      cp --dereference {jou_file_rpath} {output_dir} && \
      cp --dereference {log_file_rpath} {output_dir} && \
      cp -R --dereference {cache_dir_rpath} {output_dir} && \
      cp -R --dereference {hw_dir_rpath} {output_dir} && \
      cp -R --dereference {ip_user_files_dir_rpath} {output_dir} && \
      echo "BAZEL: Done" \
    """.format(
      script = script,
      vivado_path = VIVADO_PATH,
      xpr_tcl = xpr_tcl_script.path,
      xprdest = project_file.path,
      xprsrc = tmp_project_file_path,

      cache_dir_rpath = cache_dir_rpath,
      hw_dir_rpath = hw_dir_rpath,
      ip_user_files_dir_rpath = ip_user_files_dir_rpath,
      jou_file_rpath = jou_file_rpath,
      log_file_rpath = log_file_rpath,

      output_dir = output_dir.path,
    )
  )

  return (project_file, outputs, output_dir)



def _vivado_project_impl(ctx):
    # General setup
    name = ctx.attr.name
    top_level = ctx.attr.top_level

    # Get tool path
    generator = ctx.attr._generator.files
    generator_path = generator.to_list()[0]

    # Why is this data model so complicated?!
    inputs = []

    # Process srcs
    srcs_files = []
    for src_target in ctx.attr.srcs:
        srcs_files += src_target.files.to_list()
    inputs += srcs_files
    src_paths = [ f.path for f in srcs_files ]
    # Process hdrs
    hdrs_files = []
    for hdrs_target in ctx.attr.hdrs:
        hdrs_files += hdrs_target.files.to_list()
    inputs += hdrs_files
    hdrs_paths = [ f.path for f in hdrs_files ]

    # Process constraints files (.xdc)
    xdcs_files = []
    for xdcs_target in ctx.attr.xdcs:
        xdcs_files += xdcs_target.files.to_list()
    inputs += xdcs_files
    xdcs_paths = [ f.path for f in xdcs_files ]

    # Prepare include dirs
    include_dirs = ctx.attr.include_dirs  # list(string)

    # Handle output files
    outputs = []
    xpr = ctx.actions.declare_file("{}.xpr.tcl".format(name))
    outputs += [xpr]
    synth_tcl = ctx.actions.declare_file("{}.synth.tcl".format(name))
    outputs += [synth_tcl]
    pnr_tcl = ctx.actions.declare_file("{}.pnr.tcl".format(name))
    outputs += [pnr_tcl]

    # Prepare args
    args = ctx.actions.args()
    args.add("--project-name", name)
    args.add("--top-name", top_level)
    args.add_all(src_paths, before_each="--source")
    args.add_all(hdrs_paths, before_each="--header")
    args.add_all(xdcs_paths, before_each="--constraints")
    args.add_all(include_dirs, before_each="--include-dir")
    args.add_all(ctx.attr.defines, before_each="--define")
    args.add("--out-xpr", xpr.path)
    args.add("--out-synth", synth_tcl.path)
    args.add("--out-pnr", pnr_tcl.path)

    part = ctx.attr.part
    args.add("--part", part)

    #
    ctx.actions.run(
        outputs = outputs,
        inputs = inputs,
        tools = [ generator ],
        executable = generator_path,
        arguments = [ args ],
        progress_message = "XPRGEN {}",
    )
    project, other_outputs, xpr_gen_output_dir = _xpr_gen(
      ctx, srcs_files, hdrs_files, xdcs_files, include_dirs, xpr)
    outputs += other_outputs + [project]

    return [
        DefaultInfo(
          files = depset(outputs),
          runfiles = ctx.runfiles(files=outputs),
        ),
        VivadoGenProvider(
          headers = depset(hdrs_files),
          sources = depset(srcs_files),
          constraints = depset(xdcs_files),
          include_dirs = include_dirs,
          xpr_tcl_script = xpr,
          synth_tcl_script = synth_tcl,
          xpr_file = project,
          top_level = top_level,
          pnr_tcl_script = pnr_tcl,
          project_name = name,
          xpr_gen_output_dir = xpr_gen_output_dir,
          part = part,
        ),
    ]


vivado_project = rule(
    implementation = _vivado_project_impl,
    attrs = {
        "top_level": attr.string(
            doc = "Top level entity name",
            mandatory = True,
        ),
        "part": attr.string(
            doc = "The part that is targeted by this project",
            mandatory = True,
        ),
        "srcs": attr.label_list(
            allow_files = True,
        ),
        "hdrs": attr.label_list(
            allow_files = True,
        ),
        "xdcs": attr.label_list(
            allow_files = [ ".xdc" ],
            doc = "A list of constraints files to use."
        ),
        "defines": attr.string_list(
            allow_empty = True,
        ),
        "include_dirs": attr.string_list(
        ),
        "env": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of env variables to define for the run."
        ),
        "mount": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of mounts to define for the run."
        ),
        "_generator": attr.label(
            default = "//build/vivado/bin/xprgen:xprgen",
        ),
        "_script": attr.label(
            default="@bazel_rules_bid//build:docker_run",
            executable=True,
            cfg="host",
        ),
    },
)


def _vivado_synthesis_impl(ctx):
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
      "-w", "/work",
    ],
  )

  # Run vivado with the script in the container
  # The copy/chmod shenanigans are needed to work around Vivado's hostile
  # attitude towards sandboxing.
  ctx.actions.run_shell(
    progress_message = "Vivado Synthesis \"{}\"".format(name),
    inputs = inputs + [docker_run],
    outputs = outputs,
    mnemonic = "VivadoSynth",
    tools = [docker_run],
    command = """\
      echo "BAZEL: Vivado synthesis" && \
      echo "BAZEL: Vivado working directory is: $PWD" && \
      echo "BAZEL: Vivado output directory is : {output_dir_path}" && \
      mkdir -p {output_dir_path} && \
      cp --dereference {xpr_src} {xpr_file} && \
      chmod a+w {xpr_file} && \
      cp -R --dereference {xpr_gen_output_dir} $PWD && \
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
        -notrace -mode batch -source {synth_tcl} {xpr_file} && \
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
    attrs = {
        "project": attr.label(
            doc = "The Vivado project to work on",
            mandatory = True,
            providers = [VivadoGenProvider],
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
            default="@bazel_rules_bid//build:docker_run",
            executable=True,
            cfg="host",
        ),
    },
)


def _vivado_pnr_impl(ctx):
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
      "-w", "/work",
    ],
  )

  # Run vivado with the script in the container
  # The copy/chmod shenanigans are needed to work around Vivado's hostile
  # attitude towards sandboxing.
  ctx.actions.run_shell(
    progress_message = "Vivado Place and Route \"{}\"".format(name),
    inputs = inputs + [docker_run],
    outputs = outputs,
    mnemonic = "VivadoPNR",
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
            default="@bazel_rules_bid//build:docker_run",
            executable=True,
            cfg="host",
        ),
    },
)


