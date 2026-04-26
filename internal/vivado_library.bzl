"""Vivado library rule."""

load("//internal:defines.bzl",
    "VIVADO_VERSION", "CONTAINER", "VIVADO_PATH",
    _script_cmd = "script_cmd",
)
load("//internal:providers.bzl",
    "VivadoLibraryProvider",
)

def _vivado_library_impl(ctx):
    """Implementation for the vivado_library rule.

    Args:
      ctx: The rule context.

    Returns:
      A list of providers, including DefaultInfo and VivadoLibraryProvider.
    """
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
            standard_flag = ["--2008"]
            if ctx.attr.vhdl1993:
                standard_flag = []
            if ctx.attr.standard and ctx.attr.standard != "2008":
                standard_flag = ["--{}".format(ctx.attr.standard)]
            args += standard_flag

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

    log_file = ctx.actions.declare_file("{}.log".format(ctx.attr.name))
    outputs += [log_file]

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
            {args} 2>&1 > {log} || ( cat {log} && exit 1)
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            command=command,
            args=" ".join(args),
            log=log_file.path,
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
            doc = "Whether to use the global glbl.v.",
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
            default="@rules_bid//build:docker_run",
            executable=True,
            cfg="host",
            doc = "The docker run script.",
        ),
        "vhdl1993": attr.bool(
            default=False,
            doc = "Use VHDL-1993 standard else use VHDL-2008",
        ),
        "standard": attr.string(
            default = "2008",
            doc = "Specify the language standard to use",
        ),
    },
)
