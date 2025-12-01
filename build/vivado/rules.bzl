load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_rules_bid//build:rules.bzl", "run_docker_cmd")

_DOCKER_RUN_SCRIPT_ATTRS = {
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
}

VivadoLibraryProvider = provider(
    "A library of files used for vivado",
    fields = {
        "name": "The library name",
        "files": "The list of files comprising this library",
        "hdrs": "The list of headers in this library",
        "includes": "The list of include dirs in this library.",
        "deps": "A depset of other providers",
        "deps_names": "A depset of library names contained in `deps`",
        "library_dir": "A Vivado compiled library directory",
        "unisims_libs": "A boolean",
    }
)


VivadoGenProvider = provider(
  "Information about generated vivado files",
  fields = {
    "sources": "The list of the module's source files",
    "deps": "Libraries",
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
    "synth_dcp_file": "The DCP file of synthesis step"
  },
)

VivadoBitstreamProvider = provider(
  "Information about the bitstream",
  fields = {
    "bitstream": "The bitstream to program into the FPGA",
  },
)

VIVADO_VERSION = "2025.1"
# This needs to exist on your computer before we begin.
CONTAINER = "xilinx-vivado:{}".format(VIVADO_VERSION)
# This is tied to the contents of the above CONTAINER.
VIVADO_PATH = "/opt/Xilinx/{}/Vivado".format(VIVADO_VERSION)


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
        scratch_dir="{}:/tmp/.cache".format(cache_dir),
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
  deps_files,
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
  inputs = deps_files + xdcs_files + srcs_files + hdrs_files + [xpr_tcl_script]

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
        -notrace -mode batch -source {xpr_tcl} 1>&2 && \
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
    args = ctx.actions.args()

    # General setup
    name = ctx.attr.name
    top_level = ctx.attr.top_level

    # Get tool path
    generator = ctx.attr._generator.files
    generator_path = generator.to_list()[0]

    # Why is this data model so complicated?!
    inputs = []
    xdcs_files = []
    outputs = []
    deps_files = []
    srcs_files = []
    hdrs_files = []

    # Get library deps.
    seen_libraries = []
    for dep in ctx.attr.deps:
        # process dep deps.
        provider = dep[VivadoLibraryProvider]

        for provider_dep in provider.deps.to_list():
            lib_name = provider_dep.name
            if lib_name not in seen_libraries:
                seen_libraries += [lib_name]

                provider_dep_files = provider_dep.files
                for file in provider_dep_files:
                    inputs += [file]
                    deps_files += [file]
                    args.add("--library-file", "{}={}".format(lib_name, file.path))

        lib_name = provider.name
        if lib_name not in seen_libraries:
            seen_libraries += [lib_name]

            for file in provider.files:
                inputs += [file]
                deps_files += [file]
                args.add("--library-file", "{}={}".format(lib_name, file.path))

    # Process srcs
    for src_target in ctx.attr.srcs:
        srcs_files += src_target.files.to_list()
    inputs += srcs_files
    src_paths = [ f.path for f in srcs_files ]

    # Process hdrs
    for hdrs_target in ctx.attr.hdrs:
        hdrs_files += hdrs_target.files.to_list()
    inputs += hdrs_files
    hdrs_paths = [ f.path for f in hdrs_files ]

    # Process constraints files (.xdc)
    for xdcs_target in ctx.attr.xdcs:
        xdcs_files += xdcs_target.files.to_list()
    inputs += xdcs_files
    xdcs_paths = [ f.path for f in xdcs_files ]

    # Prepare include dirs
    include_dirs = ctx.attr.include_dirs  # list(string)

    # Handle output files
    xpr = ctx.actions.declare_file("{}.xpr.tcl".format(name))
    outputs += [xpr]
    synth_tcl = ctx.actions.declare_file("{}.synth.tcl".format(name))
    outputs += [synth_tcl]
    pnr_tcl = ctx.actions.declare_file("{}.pnr.tcl".format(name))
    outputs += [pnr_tcl]


    # Prepare args
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
        progress_message = "Generating Vivado Project {}".format(name),
        mnemonic = "XPRGEN"
    )
    project, other_outputs, xpr_gen_output_dir = _xpr_gen(
      ctx, srcs_files, hdrs_files, xdcs_files, include_dirs, xpr, deps_files)
    outputs += other_outputs + [project]

    return [
        DefaultInfo(
          files = depset(outputs+srcs_files),
          runfiles = ctx.runfiles(files=outputs+srcs_files),
        ),
        VivadoGenProvider(
          headers = depset(hdrs_files),
          sources = depset(srcs_files+deps_files),
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
        "deps": attr.label_list(
            providers = [VivadoLibraryProvider],
            doc = "The list of library dependencies",
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
            default=Label("@bazel_rules_bid//build:docker_run"),
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
    attrs = _DOCKER_RUN_SCRIPT_ATTRS | {
        "project": attr.label(
            doc = "The Vivado project to work on",
            mandatory = True,
            providers = [VivadoGenProvider],
        ),
    },
)


def _vivado_synthesis2_impl(ctx):
    args = ctx.actions.args()

    # General setup
    name = ctx.attr.name
    top_level = ctx.attr.top

    # Get tool path
    generator = ctx.attr._generator.files
    generator_path = generator.to_list()[0]

    # Why is this data model so complicated?!
    inputs = []
    outputs = []
    deps_files = []
    srcs_files = []
    hdrs_files = []
    xdcs_files = []

    # Template file.
    template_file = ctx.attr._synth_batch_template.files.to_list()[0]
    inputs += [template_file]

    # Get library deps.
    seen_libraries = []
    for dep in ctx.attr.deps:
        provider = dep[VivadoLibraryProvider]

        for provider_dep in provider.deps.to_list():
            lib_name = provider_dep.name
            if lib_name not in seen_libraries:
                seen_libraries += [lib_name]

                provider_dep_files = provider_dep.files
                for file in provider_dep_files:
                    inputs += [file]
                    deps_files += [file]
                    args.add("--library-file", "{}={}".format(lib_name, file.path))

        lib_name = provider.name
        if lib_name not in seen_libraries:
            seen_libraries += [lib_name]

            for file in provider.files:
                inputs += [file]
                deps_files += [file]
                args.add("--library-file", "{}={}".format(lib_name, file.path))

    # Process srcs
    for src_target in ctx.attr.srcs:
        srcs_files += src_target.files.to_list()
    inputs += srcs_files
    src_paths = [ f.path for f in srcs_files ]

    # Process hdrs
    for hdrs_target in ctx.attr.hdrs:
        hdrs_files += hdrs_target.files.to_list()
    inputs += hdrs_files
    hdrs_paths = [ f.path for f in hdrs_files ]

    # Process constraints files (.xdc)
    for xdcs_target in ctx.attr.xdcs:
        xdcs_files += xdcs_target.files.to_list()
    inputs += xdcs_files
    xdcs_paths = [ f.path for f in xdcs_files ]
    # Prepare include dirs
    include_dirs = ctx.attr.include_dirs  # list(string)

    # Handle output files
    dcp_file = ctx.actions.declare_file("{}.dcp".format(name))
    outputs += [dcp_file]

    timing_summary_file = ctx.actions.declare_file("{}.timing_summary_synth.rpt".format(name))
    outputs += [timing_summary_file]
    utilization_file = ctx.actions.declare_file("{}.utilization_synth.rpt".format(name))
    outputs += [utilization_file]

    tcl_file = ctx.actions.declare_file("{}.synth.tcl".format(name))

    processed_defines = []
    for k, v in ctx.attr.defines.items():
        expanded = ctx.expand_location(v, targets = ctx.attr.data)
        processed_defines += ["{}={}".format(k, expanded)]
    processed_generics = []
    for k, v in ctx.attr.generics.items():
        expanded = ctx.expand_location(v, targets = ctx.attr.data)
        processed_generics += ["{}={}".format(k, expanded)]

    # data_files = [ file for file in target.files.to_list() for target in ctx.attr.data ]
    # ???
    data_files = []
    for target in ctx.attr.data:
        for file in target.files.to_list():
            data_files += [file]
    inputs += data_files


    # Prepare args
    args.add("--custom-filename", tcl_file.path)
    args.add("--custom-template", template_file.path)
    args.add("--project-name", name)
    args.add("--save-dcp", dcp_file.path)
    args.add("--timing-report", timing_summary_file.path)
    args.add("--top-name", top_level)
    args.add("--utilization-report", utilization_file.path)
    args.add_all(processed_defines, before_each="--define")
    args.add_all(processed_generics, before_each="--generic")
    args.add_all(hdrs_paths, before_each="--header")
    args.add_all(include_dirs, before_each="--include-dir")
    args.add_all(src_paths, before_each="--source")
    args.add_all(xdcs_paths, before_each="--constraints")


    part = ctx.attr.part
    args.add("--part", part)

    # Generate `tcl_file` script for running the synth step.
    ctx.actions.run(
        outputs = [tcl_file],
        inputs = inputs,
        tools = [ generator ],
        executable = generator_path,
        arguments = [ args ],
        progress_message = "Vivado Synth XPRGEN {}".format(name),
        mnemonic = "XPRGEN",
    )

    # Prepare the docker mount.
    docker_run = ctx.executable._script
    env = ctx.attr.env
    mounts = {}
    if ctx.attr.mount:
      mounts.update(ctx.attr.mount)
    mounts.update({
      "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
    })

    output_dir_path = "_synthesis.work.{}".format(name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    cache_dir_rpath = "_synthesis.cache.{}".format(name)
    cache_dir = ctx.actions.declare_directory(cache_dir_rpath)

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

    inputs += [tcl_file]

    ctx.actions.run_shell(
        progress_message = "Vivado Synthesis {}".format(name),
        inputs = inputs + [docker_run],
        outputs = outputs + [output_dir, cache_dir],
        tools = [docker_run],
        mnemonic = "VivadoSynth",
        command = """\
            mkdir -p {cache} &&
            mkdir -p {work} && \
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh vivado \
                -notrace -mode batch -source {synth_tcl} 1>&2
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            synth_tcl=tcl_file.path,
            cache=cache_dir.path,
            work=output_dir.path,
        ),
    )

    return [
        DefaultInfo(
            # DCP outfile, plus reports.
            files = depset(outputs),
        ),
        VivadoSynthProvider(
            synth_dcp_file = dcp_file,
        ),
    ]


vivado_synthesis2 = rule(
    implementation = _vivado_synthesis2_impl,
    attrs = _DOCKER_RUN_SCRIPT_ATTRS | {
        "srcs": attr.label_list(
            allow_files = True,
            doc = "The sources for the `work` library",
        ),
        "hdrs": attr.label_list(
            doc = "The headers for the `work` library if verilog",
        ),
        "deps": attr.label_list(
            doc = "The sources for the libraries",
            providers = [VivadoLibraryProvider],
        ),
        "data": attr.label_list(
            doc = "Other data",
        ),
        "xdcs": attr.label_list(
            doc = "Constraint files",
        ),
        "top": attr.string(
            doc = "Mandatory name of the top level entity",
            mandatory = True,
        ),
        "part": attr.string(
            doc = "The part that is targeted by this project",
            mandatory = True,
        ),
        "defines": attr.string_dict(
            allow_empty = True,
        ),
        "generics": attr.string_dict(
            allow_empty = True,
        ),
        "include_dirs": attr.string_list(
            allow_empty = True,
        ),
        "_generator": attr.label(
            doc = "xprgen binary",
            default = Label("//build/vivado/bin/xprgen"),
            executable = True,
            cfg = "host",
        ),
        "_synth_batch_template": attr.label(
            doc = "synth template",
            default = Label("//build/vivado:synth_batch_tcl_template"),
        ),
        # Probably need verilog top level params and vhdl top level generics.
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
            default="@bazel_rules_bid//build:docker_run",
            executable=True,
            cfg="host",
        ),
    },
)


def _vivado_place_and_route2_impl(ctx):
    args = ctx.actions.args()
    name = ctx.attr.name
    generator = ctx.attr._generator.files
    generator_path = generator.to_list()[0]
    inputs = []
    outputs = []

    template_file = ctx.attr._batch_template.files.to_list()[0]
    inputs += [template_file]

    tcl_file = ctx.actions.declare_file("{}.pnr.tcl".format(name))
    outputs += [tcl_file]

    input_dcp_file = ctx.attr.synthesis[VivadoSynthProvider].synth_dcp_file

    output_dcp_file = ctx.actions.declare_file("{}.pnr.dcp".format(name))
    outputs += [output_dcp_file]
    drc_report_file = ctx.actions.declare_file("{}.drc.rpt".format(name))

    timing_summary_file = ctx.actions.declare_file("{}.timing_summary.pnr.rpt".format(name))
    outputs += [timing_summary_file]
    utilization_file = ctx.actions.declare_file("{}.utilization.pnr.rpt".format(name))
    outputs += [utilization_file]
    bit_file = ctx.actions.declare_file("{}.bit".format(name))

    xdc_files = []
    xdc_files_paths = []
    for target in ctx.attr.xdcs:
        xdc_files_paths += [ file.path for file in target.files.to_list() ]
        xdc_files += target.files.to_list()
    inputs += xdc_files

    args.add("--custom-filename", tcl_file.path)
    args.add("--custom-template", template_file.path)
    args.add("--load-dcp", input_dcp_file.path)
    args.add("--save-dcp", output_dcp_file.path)
    args.add("--timing-report", timing_summary_file.path)
    args.add("--utilization-report", utilization_file.path)
    args.add("--drc-report", drc_report_file.path)
    args.add("--top-name", name)
    args.add("--bitstream", bit_file.path)
    args.add_all(xdc_files_paths, before_each = "--constraints")

    ctx.actions.run(
        outputs = [tcl_file],
        inputs = inputs,
        tools = [ generator ],
        executable = generator_path,
        arguments = [ args ],
        progress_message = "Vivado PNR XPRGEN {}".format(name),
        mnemonic = "XPRGEN",
    )

    # PNR step here.

    # Prepare the docker mount.
    docker_run = ctx.executable._script
    env = ctx.attr.env
    mounts = {}
    if ctx.attr.mount:
      mounts.update(ctx.attr.mount)
    mounts.update({
      "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
    })

    output_dir_path = "_pnr.work.{}".format(name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    cache_dir_rpath = "_pnr.cache.{}".format(name)
    cache_dir = ctx.actions.declare_directory(cache_dir_rpath)

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

    outputs = [output_dcp_file, drc_report_file, timing_summary_file, utilization_file, bit_file]
    inputs = [tcl_file, input_dcp_file] + xdc_files

    ctx.actions.run_shell(
        progress_message = "Vivado Synthesis {}".format(name),
        inputs = inputs + [docker_run],
        outputs = outputs + [output_dir, cache_dir],
        tools = [docker_run],
        mnemonic = "VivadoSynth",
        command = """\
            mkdir -p {cache} &&
            mkdir -p {work} && \
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh vivado \
                -notrace -mode batch -source {tcl} 1>&2
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            tcl=tcl_file.path,
            cache=cache_dir.path,
            work=output_dir.path,
        ),
    )
    return [
        DefaultInfo(files=depset([
            bit_file,
            utilization_file,
            timing_summary_file,
            drc_report_file,
            output_dcp_file,
        ])),
        VivadoBitstreamProvider(
            bitstream = bit_file,
        ),
    ]


vivado_place_and_route2 = rule(
    implementation = _vivado_place_and_route2_impl,
    attrs = _DOCKER_RUN_SCRIPT_ATTRS | {
        "synthesis": attr.label(
            doc = "The mandatory synth2 target to use",
            mandatory = True,
            providers = [VivadoSynthProvider],
        ),
        "xdcs": attr.label_list(
            doc = "Constraint files",
        ),
        "_generator": attr.label(
            doc = "xprgen binary",
            default = Label("//build/vivado/bin/xprgen"),
            executable = True,
            cfg = "host",
        ),
        "_batch_template": attr.label(
            doc = "pnr template",
            default = Label("//build/vivado:pnr_batch_tcl_template"),
        ),
    },
)


def _vivado_program_device(ctx):
    # For now, only one bitstream.
    bitstream = None
    bittarget = None
    for target in ctx.attr.deps:
        bittarget = target
        for file in target.files.to_list():
            bitstream = file
            break


    bitstream_provider = bittarget[VivadoBitstreamProvider]
    bitfile = bitstream_provider.bitstream

    # Needed binaries
    script = ctx.attr._script.files.to_list()[0]
    gotopt2 = ctx.attr._gotopt2.files.to_list()[0]
    generator = ctx.attr._proggen.files.to_list()[0]

    data = ctx.attr._data.files.to_list()

    # These do not seem to be stable; why?
    tpl1 = data[1]
    yaml = data[0]


    # Generated script file.
    daemon_inputs = []
    daemon_outputs = []
    default_runfiles = []
    #if ctx.attr.prog_daemon:
        #daemon_runfiles = ctx.attr.prog_daemon[DefaultInfo].default_runfiles
        #default_runfiles += [daemon_runfiles]
        #daemon_file = ctx.actions.declare_file("{}.daemon".format(ctx.attr.name))
        #daemon_outputs = [daemon_file]
        #args_daemon = ctx.actions.args()
        #args_daemon.add("--stamp-file", daemon_file.path)
        #if ctx.attr.prog_daemon_args:
            #subst = [ ctx.expand_location(t, targets=ctx.attr.data) for t in ctx.attr.prog_daemon_args]
            #args_daemon.add_all(subst)
        #daemon_inputs = []
        #runfiles = ctx.runfiles(files=ctx.files.data)
        #transitive_runfiles = default_runfiles
        #data_files = []
        #for target in ctx.attr.data:
            #daemon_inputs += target.files.to_list()
            #transitive_runfiles.append(target[DefaultInfo].default_runfiles)
            #data_files += target[DefaultInfo].data_runfiles.files.to_list()
        #runfiles = runfiles.merge_all(transitive_runfiles)

        #print("runfiles: ", runfiles.files)

        #for t in ctx.attr.data:
            #data_files += t.files.to_list()

        #print("data files: ", data_files)

        #ctx.actions.run(
            #inputs = daemon_inputs + data_files + runfiles.files.to_list(),
            #outputs = daemon_outputs,
            #executable = ctx.attr.prog_daemon.files.to_list()[0],
            #arguments = [args_daemon],
            #mnemonic = "DAEMON",
            #progress_message = "Running programming daemon: {}".format(daemon_file.path),
        #)

    outfile = ctx.actions.declare_file("{}.sh".format(ctx.attr.name))
    args = ctx.actions.args()
    args.add("--outfile", outfile.path)
    args.add("--gotopt2", gotopt2.path)
    args.add("--run-docker", script.path)
    args.add("--template", tpl1.path)
    args.add("--bitfile", bitfile.short_path)

    # Add runner arguments here.
    prog_runner_args = ctx.expand_location(
        " ".join(ctx.attr.prog_daemon_args),
        targets=ctx.attr.data)
    args.add("--prog-runner-args={}".format(prog_runner_args))
    args.add("--prog-runner-binary", ctx.attr.prog_daemon.files.to_list()[0].short_path)

    ctx.actions.run(
        inputs = [generator, gotopt2, script, bitfile] + daemon_outputs,
        outputs = [outfile],
        executable = generator,
        tools = [
            gotopt2, script
        ] + data,
        arguments = [args],
        mnemonic = "PROGGEN",
        progress_message = "Generating programming script: {}".format(outfile.path),
    )

    runfiles = ctx.runfiles(
        files=[script, gotopt2, yaml, bitfile],
        collect_data = True,
    )

    default_runfiles += [
        ctx.attr._script[DefaultInfo].default_runfiles,
        ctx.attr._proggen[DefaultInfo].default_runfiles,
        ctx.attr._data[DefaultInfo].default_runfiles,
        ctx.attr._gotopt2[DefaultInfo].default_runfiles,
        ctx.attr.prog_daemon[DefaultInfo].default_runfiles,
    ]

    runfiles = runfiles.merge_all(default_runfiles)

    return [
        DefaultInfo(
            files=depset([outfile, yaml, gotopt2]),
            runfiles=runfiles,
            executable = outfile,
        )
    ]

vivado_program_device = rule(
    implementation = _vivado_program_device,
    executable = True,
    attrs = {
        "deps": attr.label_list(
            providers = [VivadoBitstreamProvider],
            doc = "The list of deps containing bitstream code",
        ),
        "_script": attr.label(
            default="@bazel_rules_bid//build:docker_run",
            executable=True,
            cfg="host",
        ),
        "_gotopt2": attr.label(
            default="@gotopt2//:bin",
            executable=True,
            cfg="host",
        ),
        "_proggen": attr.label(
            default=Label("//build/vivado/bin/proggen"),
            executable=True,
            cfg="host",
            doc = "The program to generate a programming wrapper",
        ),
        "_data": attr.label(
            default=Label("//build/vivado/bin/proggen:data"),
            doc = "The program to generate a programming wrapper",
            providers = ["files"],
        ),
        "prog_daemon": attr.label(
            doc = "The binary to start before programming",
            executable = True,
            cfg = "host",
        ),
        "prog_daemon_args": attr.string_list(
            doc = "The args to give to prog_daemon, subject to make var substitution",
        ),
        "data": attr.label_list(
            doc = "The list of dependencies to expand",
        ),
    },
)


def _vivado_library_impl(ctx):
    args = [] # Not using ctx.actions.args() because of the very specific scripting.
    # Process inputs to the compilation.
    inputs = []
    # Handle direct files.
    files = []

    for target in ctx.attr.data:
        inputs += [file for file in target.files.to_list()]

    srcs_targets = ctx.attr.srcs
    for target in srcs_targets:
        files += [file for file in target.files.to_list()]

    provider_direct_list = []
    provider_transitive_depsets = []

    transitive_files = []
    deps_names_direct = []
    deps_names_transitive = []
    deps_names_transitive_depsets = []
    for dep in ctx.attr.deps:
        provider = dep[VivadoLibraryProvider]

        # Special-casing unisims, will be processed below too.
        if provider.unisims_libs:
            dep_names_depset = provider.deps_names
            deps_names_transitive += dep_names_depset.to_list()
            deps_names_transitive_depsets += [dep_names_depset]

            provider_direct_list += [provider]
            provider_transitive_depsets += [provider.deps]
        else:
            dep_library_name = provider.name

            dep_names_depset = provider.deps_names
            deps_names_transitive += dep_names_depset.to_list()
            deps_names_transitive_depsets += [dep_names_depset]

            if not dep_library_name in deps_names_transitive:
                deps_names_direct += [dep_library_name]

                transitive_files += [ depset(direct=provider.files) ]

                provider_direct_list += [provider]
                provider_transitive_depsets += [provider.deps]

    # Fixup library name. By default it is the target name. But if the target
    # name for some reason can not be used, allow the user to specify
    # library_name instead.
    library_name = ctx.attr.name
    if ctx.attr.library_name:
        library_name = ctx.attr.library_name

    outputs = []
    # The directory to output the library info.  Will probably end up having
    # subdirectories.
    library_output_dir = ctx.actions.declare_directory(
        "target-{}.lib-{}.hdlib".format(ctx.attr.name, library_name))
    outputs += [library_output_dir]

    # Not sure if all of these are required
    output_dir_path = "_xvlog_gen.work.{}".format(ctx.attr.name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    outputs += [output_dir]
    cache_dir = ctx.actions.declare_directory(
      "_xvlog_gen.cache.{}".format(ctx.label.name))
    outputs += [cache_dir]


    # Prepare to run xvlog/xvhdl
    docker_run = ctx.executable._script
    env = ctx.attr.env
    mounts = {}
    if ctx.attr.mount:
      mounts.update(ctx.attr.mount)
    mounts.update({
      "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
    })

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

    inputs += files
    # Header files are rule inputs, but they do not appear on the command line.
    hdrs = []
    for target in ctx.attr.hdrs:
        hdrs += target.files.to_list()

    # Determine the compilation command
    command = None
    library_type = None
    for file in files:
        if file.extension == "v": # Verilog (ordinary)
            if command and command != "xvlog":
                fail("can not mix VHDL and Verilog files in the same library")
            command = "xvlog"
            library_type = "Verilog"
        if file.extension == "sv": # SystemVerilog
            if command and command != "xvlog":
                fail("can not mix VHDL and SystemVerilog files in the same library")
            command = "xvlog"
            args += ["--sv"]
            library_type = "SystemVerilog"
        if file.extension == "vhd" or file.extension == "vhdl": # Vhdl
            if command and command != "xvhdl":
                fail("cann ot mix VHDL  with Verilog in the same library")
            command = "xvhdl"
            library_type = "VHDL"
            # VHDL 2008 is used by default, use bool flag `vhdl1993 = True`
            # to revert to 1993.
            if not ctx.attr.vhdl1993:
                args += ["--2008"]

    args += ["--work", "{}={}".format(library_name, library_output_dir.path)]

    # Handle include directories
    for include in ctx.attr.includes:
        full_include = None
        if include[:2] == "//":
            full_include = include[2:]
        elif include in ["", "."]:
            full_include = ctx.attr.package
        else:
            full_include = "/".join([ctx.attr.package, include])
        args += ["-i", full_include]

    # Handle dependency libraries.
    for dep in ctx.attr.deps:
        provider = dep[VivadoLibraryProvider]

        if provider.unisims_libs:
            unisims_dir=provider.library_dir
            inputs += [unisims_dir]
            for dep_library_name in provider.deps_names.to_list():
                args += ["--lib", "{lib_name}={dir_path}/{lib_name}".format(
                    dir_path=unisims_dir.path,
                    lib_name=dep_library_name)]
        else:
            dep_library_name = provider.name
            dep_library_dir = provider.library_dir
            args += ["--lib", "{}={}".format(dep_library_name, dep_library_dir.path)]
            inputs += [dep_library_dir]

    # Macro values to define when analyzing this library.
    defines = []
    for k, v in ctx.attr.defines.items():
        if v:
            # For `ifdef foo=bar
            defines += ["-d", "{}={}".format(k,v)]
        else:
            # For `ifdef foo
            defines += ["-d", "{}".format(k)]
    if command == "xvlog":
        args += defines

    for file in files:
        args += [file.path]

    # Special Vivado sauce.
    if ctx.attr.use_glbl:
        command = "xvlog"
        args = ["{}/data/verilog/src/glbl.v".format(VIVADO_PATH)] + args

    ctx.actions.run_shell(
        progress_message = "Vivado compile {} library \"{}\"".format(
            library_type, library_name),
        inputs = inputs + hdrs + [docker_run],
        outputs = outputs,
        mnemonic = "Vivado{}".format(library_type),
        tools = [docker_run],
        command = """\
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh {command} \
            {args} 1>&2
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            command=command,
            args=" ".join(args),
        ),
    )

    # Build correct depsets (hopefully...)
    files_depset = depset(
        files+[library_output_dir],
        transitive=transitive_files,
        order="postorder") # All files, no library distinction.
    deps_names=depset(deps_names_direct, transitive=deps_names_transitive_depsets, order="postorder") # All deps library names.
    deps = depset(provider_direct_list, transitive=provider_transitive_depsets, order="postorder")

    vivado_provider = VivadoLibraryProvider(
        name=library_name,
        files=files, # Only direct files, not transitive.
        includes=depset(ctx.attr.includes),
        hdrs=depset(hdrs),
        deps=deps,
        deps_names=deps_names,
        library_dir=library_output_dir,
        unisims_libs=False,
    )

    return [
        DefaultInfo(files=files_depset),
        vivado_provider,
    ]

vivado_library = rule(
    implementation = _vivado_library_impl,
    attrs = {
        "srcs": attr.label_list(
            # I think that Verilog does not have libraries.
            allow_files = [ "vhd", "vhdl", "v", "sv" ],
            doc = "The list of files in this library",
        ),
        "hdrs": attr.label_list(
            allow_files = [ "h", "vh", "svh", ],
            doc = "The list of include files in this library",
        ),
        "data": attr.label_list(
            doc = "The list of target that should be available for compilation.",
        ),
        "deps": attr.label_list(
            allow_files = True,
            doc = "The list of files in this library",
            providers = [VivadoLibraryProvider],
        ),
        "includes": attr.string_list(
            doc = "The list of additional directories to append to the include list",
        ),
        "defines": attr.string_dict(
            doc = "The list of key-to-value mappings to apply to the compilation",
        ),
        "library_name": attr.string(
            doc = """An optional library name, in the case the target name
                     can not be used for some reason."""
        ),
        "use_glbl": attr.bool(
            default=False,
        ),
        # These parameters are part of the docker_run setup.
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
        "vhdl1993": attr.bool(
            default=False,
            doc = "Use VHDL-1993 standard else use VHDL-2008",
        ),
    },
)



def vivado_generics(name, verilog_top=None, vhdl_top=None, params={}, generics={}, data=None, synth=None):
    out_name = "{}.tcl".format(name)
    args = []
    for k, v in params.items():
        args +=  [
            "--param={}={}".format(k, v),
    ]
    if verilog_top:
        args += ["--verilog-top", verilog_top]

    for k, v in generics.items():
        args +=  [
            "--generic={}={}".format(k, v),
    ]
    if vhdl_top:
        args += ["--vhdl-top", vhdl_top]
    native.genrule(
        name=name,
        srcs=data,
        outs = [ out_name ],
        tools = [ Label("@rules_vivado//bin/genparams") ] + data,
        cmd = """$(location @rules_vivado//bin/genparams) {} > $@""".format(" ".join(args)),
    )


def _vivado_simulation_impl(ctx):
    args = []
    files = []
    # elaborate first

    provider = ctx.attr.library[VivadoLibraryProvider]
    deps_depset = provider.deps
    args += ["-L", "{}={}".format(provider.name, provider.library_dir.path)]
    args += ["--debug", "typical"]
    for dep in provider.deps.to_list():
        dep_provider = dep
        if dep_provider.unisims_libs:
            files += [dep_provider.library_dir]
            for unisim_lib in dep_provider.deps_names.to_list():
                args += ["-L", "{lib_name}={dir_name}/{lib_name}".format(
                    lib_name=unisim_lib,
                    dir_name=dep_provider.library_dir.path)]
        else:
            files += [file for file in dep_provider.files]
            files += [dep_provider.library_dir]
            args += ["-L", "{}={}".format(
                dep_provider.name, dep_provider.library_dir.path)]

    files += [file for file in provider.files]
    files += [provider.library_dir]

    top_entity = ctx.attr.top
    if ctx.attr.config:
        top_entity = ctx.attr.config
    args += ["--top", "'{}.{}'".format(provider.name, top_entity)]
    args += ctx.attr.extra_modules

    #print(ctx.attr.defines)
    for (k, v) in ctx.attr.defines.items():
        if v:
            # For `ifdef foo=bar
            args += ["-d", "{}={}".format(k,ctx.expand_location(v, ctx.attr.data))]
        else:
            # For `ifdef foo
            args += ["-d", "{}".format(k)]
    generic_tops = []
    for (k, v) in ctx.attr.generic_tops.items():
        # For `ifdef foo=bar
        generic_tops += ["-generic_top", '{}={}'.format(
            k,ctx.expand_location(v, ctx.attr.data))]

    data_files = []
    for target in ctx.attr.data:
        data_files += target.files.to_list()

    # The unit to elaborate.
    snapshot_name = "{}.{}.snapshot".format(provider.name, ctx.attr.top)
    args += ["--snapshot", snapshot_name]

    outputs = []
    # This is where the snapshot is located.
    xsim_dir = ctx.actions.declare_directory("{}.xsim.dir".format(ctx.label.name))
    outputs += [xsim_dir]

    # Prepare to run xelab.
    docker_run = ctx.executable._script
    env = ctx.attr.env
    mounts = {}
    if ctx.attr.mount:
      mounts.update(ctx.attr.mount)
    mounts.update({
      "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
    })

    # Outputs
    output_dir_path = "_xpr_gen.work.{}".format(ctx.label.name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    outputs += [output_dir]
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

    if ctx.attr.xelab_relaxed:
        # Relaxed checks, sometimes needed with verilog modules.
        args += ["--relax"]

    args += generic_tops
    # xelab apparently can not set the location of xsim.dir, so move it to a
    # predictable place.
    suffix = ["&&", "mv xsim.dir {}".format(xsim_dir.path)]
    ctx.actions.run_shell(
        progress_message = "Vivado elaborate library \"{}\"".format(provider.name),
        inputs = files + data_files + [docker_run],
        outputs = outputs,
        mnemonic = "VivadoElab",
        tools = [docker_run],
        command = """\
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh {command} \
            {args} 1>&2 {suffix}
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            command="xelab",
            args=" ".join(args),
            suffix=" ".join(suffix),
        ),
    )

    # Template script file for running xsim
    vcd_file = ctx.actions.declare_file(
        "{}.vcd".format(ctx.label.name))
    vcd_file_raw = ctx.actions.declare_file(
        "{}.raw.vcd".format(ctx.label.name))
    xsim_script_file = ctx.actions.declare_file(
        "{}.xsim.tcl".format(ctx.label.name))
    ctx.actions.expand_template(
        output = xsim_script_file,
        template = ctx.attr.template.files.to_list()[0],
        substitutions = {
            "{{VCD_FILE}}": vcd_file_raw.path,
            "{{TOP}}": ctx.attr.top,
        },
    )

    args = []
    inputs2 = [xsim_dir, xsim_script_file, provider.library_dir]
    #args += ["--xsimdir", "{}/xsim.dir".format(xsim_dir.path)]
    args += ["--tclbatch", xsim_script_file.path]
    outputs2 = [vcd_file_raw]
    args += ["--vcdfile", vcd_file_raw.path]
    wdb_file = ctx.actions.declare_file(
        "{}.wdb".format(ctx.label.name))
    outputs2 += [wdb_file]
    args += ["--wdb", wdb_file.path]
    args += [snapshot_name]

    # We must fix up the non-relocatability of xsim.dir.
    prefix = ["cp -R {}/xsim.dir ./xsim.dir".format(xsim_dir.path), "&&"]

    ctx.actions.run_shell(
        progress_message = "Vivado simulate \"{}.{}\"".format(provider.name, ctx.attr.top),
        inputs = inputs2 + [docker_run] + data_files ,
        outputs = outputs2,
        mnemonic = "VivadoXsim",
        tools = [docker_run],
        command = """\
            {prefix} \
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh {command} \
            {args} 1>&2
        """.format(
            prefix=" ".join(prefix),
            script=script,
            vivado_path=VIVADO_PATH,
            command="xsim",
            args=" ".join(args),
        ),
    )

    # Create raw file
    vcd_top = ctx.attr.top
    vcd_cfg = ""
    if ctx.attr.config:
        vcd_cfg = "_" + ctx.attr.config
    ctx.actions.run_shell(
        progress_message = "Fixing up VCD",
        inputs = [vcd_file_raw],
        outputs = [vcd_file],
        mnemonic = "FixVCD",
        command = """
            sed -e "s/^\\$scope module.*{top}.*{cfg}\\\\\\\\/\\$scope module {top}/g"  \\
                    < {infile} > {outfile}
        """.format(
            infile=vcd_file_raw.path, outfile=vcd_file.path,
            top=vcd_top, cfg=vcd_cfg,
        )
    )

    return [
        DefaultInfo(
          files = depset([wdb_file, vcd_file]),
        ),
        OutputGroupInfo(
            vcd = [vcd_file],
            wdb = [wdb_file],
        ),
    ]

vivado_simulation = rule(
    implementation = _vivado_simulation_impl,
    attrs = {
        "library": attr.label(
            doc = "The library to run the simulation from",
            providers = [VivadoLibraryProvider],
        ),
        "top": attr.string(
            doc = "Name of the top level entity to simulate",
        ),
        "config": attr.string(
            doc = "If specified, the said named configuration will be selected (VHDL)",
            mandatory = False,
        ),
        "extra_modules": attr.string_list(
            doc = "Names of additional modules to co-simulate",
        ),
        "defines": attr.string_dict(
            doc = "The list of key-to-value mappings to apply to the compilation",
        ),
        "generic_tops": attr.string_dict(
            doc = "The list of key-to-value mappings to apply to the compilation",
        ),
        # These parameters are part of the docker_run setup.
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
        "template": attr.label(
            allow_single_file = [".tcl.template"],
            default="xsim.tcl.template",
        ),
        "data": attr.label_list(
        ),
        "xelab_relaxed": attr.bool(
            doc = "Relax HDL checks, sometimes needed for Verilog modules",
        ),
    },
)


def _vivado_unisims_library_impl(ctx):
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
    output_dir2 = ctx.actions.declare_directory("{}.unisims.top".format(ctx.label.name))
    outputs += [output_dir2]

    inputs = []
    compile_script_file = ctx.actions.declare_file(
        "{}.compile.tcl".format(ctx.label.name))
    inputs += [compile_script_file]

    bool_flags = []
    if ctx.attr.force:
        bool_flags += ["-force"]
    if ctx.attr.quiet:
        bool_flags += ["-quiet"]
    if ctx.attr.verbose:
        bool_flags += ["-verbose"]
    if ctx.attr.no_ip_compile:
        bool_flags += ["-no_ip_compile"]
    if ctx.attr.no_systemc_compile:
        bool_flags += ["-no_systemc_compile"]

    libraries = []
    for lib in ctx.attr.libraries:
        libraries+= ["-library", lib]

    ctx.actions.expand_template(
        output = compile_script_file,
        template = ctx.attr.template.files.to_list()[0],
        substitutions = {
            "{{COMMENT}}": "Generated file do not edit.",
            "{{SIMULATOR}}": ctx.attr.simulator,
            "{{FAMILY}}": ctx.attr.family,
            "{{LANGUAGE}}": ctx.attr.language,
            "{{OUTPUT_DIR}}": output_dir2.path,
            "{{LIBRARIES}}": " ".join(libraries),
            "{{SKIP_LIBRARIES}}": " ".join(ctx.attr.skip_libraries),
            "{{BOOL_FLAGS}}": " ".join(bool_flags),
        },
    )
    #args = ["-batch", compile_script_file.path]
    args = ["-mode", "batch", "-script", compile_script_file.path]
    ctx.actions.run_shell(
        progress_message = "Vivado compile unisims {}.{}.{}".format(
            ctx.label.name, ctx.attr.family, ctx.attr.language),
        inputs = inputs + [docker_run],
        outputs = outputs,
        mnemonic = "VivadoXsim",
        tools = [docker_run],
        command = """\
            {script} \
            LD_LIBRARY_PATH="{vivado_path}/lib/lnx64.o" \
            {vivado_path}/bin/setEnvAndRunCmd.sh {command} \
            {args} # 1>&2
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            command="vivado",
            args=" ".join(args),
        ),
    )
    return [
        DefaultInfo(files=depset([output_dir2])),
        VivadoLibraryProvider(
            name="(unisims bundle)",
            files=[],
            hdrs=[],
            includes=[],
            deps=depset([]),
            deps_names=depset(ctx.attr.export_libraries),
            library_dir=output_dir2,
            unisims_libs=True,
        ),
    ]


vivado_unisims_library = rule(
    implementation = _vivado_unisims_library_impl,
    # Options of the compile_simlib script.
    # See: https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/compile_simlib
    attrs = {
        "simulator": attr.string(
            default = "xsim",
            doc = "Name of the top level entity to simulate",
        ),
        "language": attr.string(
            default = "vhdl",
            doc = "The language to compile for: vhdl|verilog|all",
        ),
        "family": attr.string(
            default = "artix7",
            doc = "The device family to compile the library for.",
        ),
        "libraries": attr.string_list(
            default = ["unisim"],
            doc = "The libraries to compile: unisim|simprim|...|all",
        ),
        "export_libraries": attr.string_list(
            default = ["unisim", "unimacro", "unifast"],
            doc = "The libraries to make available to users.",
        ),
        "force": attr.bool(
            default = False,
        ),
        "quiet": attr.bool(
            default = False,
        ),
        "verbose": attr.bool(
            default = False,
        ),
        "no_ip_compile": attr.bool(
            default = False,
        ),
        "no_systemc_compile": attr.bool(
            default = False,
        ),
        "skip_libraries": attr.string_list(
            default = [],
            doc = "The list of libraries NOT to compile",
        ),
        "template": attr.label(
            allow_single_file = [".tcl.template"],
            default="compile_simlib.tcl.template",
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
