"""Vivado project rule."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//internal:defines.bzl",
    "VIVADO_VERSION", "CONTAINER", "VIVADO_PATH",
    _script_cmd = "script_cmd",
)
load("//internal:providers.bzl",
    "VivadoLibraryProvider",
    "VivadoGenProvider",
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
  """Generates a Vivado project file.

  Args:
    ctx: The rule context.
    srcs_files: List of source files.
    hdrs_files: List of header files.
    xdcs_files: List of constraints files.
    include_dirs: List of include directories.
    xpr_tcl_script: The TCL script to generate the project.
    deps_files: List of dependency files.

  Returns:
    A tuple containing the project file, all outputs, and the output directory.
  """
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
  logfile = ctx.actions.declare_file("{}.log".format(ctx.attr.name))
  outputs += [logfile]

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
        -notrace -mode batch -source {xpr_tcl} 2>&1 > {name} || (cat {name} && exit 1) && \
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
      name = logfile.path,
    )
  )

  return (project_file, outputs, output_dir)

def _vivado_project_impl(ctx):
    """Implementation for the vivado_project rule.

    Args:
      ctx: The rule context.

    Returns:
      A list of providers, including DefaultInfo and VivadoGenProvider.
    """
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
            doc = "A list of source files.",
        ),
        "hdrs": attr.label_list(
            allow_files = True,
            doc = "A list of header files.",
        ),
        "xdcs": attr.label_list(
            allow_files = [ ".xdc" ],
            doc = "A list of constraints files to use."
        ),
        "defines": attr.string_list(
            allow_empty = True,
            doc = "A list of defines.",
        ),
        "include_dirs": attr.string_list(
            doc = "A list of include directories.",
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
            doc = "The xprgen tool.",
        ),
        "_script": attr.label(
            default=Label("@rules_bid//build:docker_run"),
            executable=True,
            cfg="host",
            doc = "The docker run script.",
        ),
    },
)
