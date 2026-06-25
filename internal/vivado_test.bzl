"""Vivado test rule."""

load("//internal:defines.bzl",
    "VIVADO_PATH",
    "DOCKER_RUN_SCRIPT_ATTRS",
    _script_cmd = "script_cmd",
)
load("//internal:providers.bzl",
    "VivadoLibraryProvider",
)

def _get_rlocation(file, ctx):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path

def _vivado_test_impl(ctx):
    """Implementation for the vivado_test rule.

    Args:
      ctx: The rule context.

    Returns:
      A list of providers.
    """
    # 1. Elaboration step (identical to vivado_simulation)
    args = []
    args += ctx.attr.xelab_args
    files = []

    provider = ctx.attr.library[VivadoLibraryProvider]
    args += ["-L", "{}={}".format(provider.name, provider.library_dir.path)]
    
    libraries = [(provider.name, provider.library_dir)]

    for dep in provider.deps.to_list():
        dep_provider = dep
        if dep_provider.unisims_libs:
            files += [dep_provider.library_dir]
            for unisim_lib in dep_provider.deps_names.to_list():
                args += ["-L", "{lib_name}={dir_name}/{lib_name}".format(
                    lib_name=unisim_lib,
                    dir_name=dep_provider.library_dir.path)]
                # For unisims, we might need to handle them specially if they are not in the same dir.
                # But usually they are.
        else:
            files += [file for file in dep_provider.files]
            files += [dep_provider.library_dir]
            args += ["-L", "{}={}".format(
                dep_provider.name, dep_provider.library_dir.path)]
            libraries.append((dep_provider.name, dep_provider.library_dir))

    files += [file for file in provider.files]
    files += [provider.library_dir]

    top_entity = ctx.attr.top
    if ctx.attr.config:
        top_entity = ctx.attr.config
    args += ["--top", "'{}.{}'".format(provider.name, top_entity)]
    args += ctx.attr.extra_modules

    for (k, v) in ctx.attr.defines.items():
        if v:
            args += ["-d", "{}={}".format(k, ctx.expand_location(v, ctx.attr.data))]
        else:
            args += ["-d", "{}".format(k)]
    
    generic_tops = []
    for (k, v) in ctx.attr.generic_tops.items():
        generic_tops += ["-generic_top", '{}={}'.format(
            k, ctx.expand_location(v, ctx.attr.data))]

    data_files = []
    for target in ctx.attr.data:
        data_files += target.files.to_list()

    snapshot_name = "{}.{}.snapshot".format(provider.name, ctx.attr.top)
    args += ["--snapshot", snapshot_name]

    outputs = []
    xsim_dir = ctx.actions.declare_directory("{}.xsim.dir".format(ctx.label.name))
    outputs += [xsim_dir]

    docker_run = ctx.executable._script
    env = ctx.attr.env
    mounts = {}
    if ctx.attr.mount:
      mounts.update(ctx.attr.mount)
    mounts.update({
      "/tmp/.X11-unix": "/tmp/.X11-unix:ro",
    })

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
      ],
    )

    if ctx.attr.xelab_relaxed:
        args += ["--relax"]

    args += generic_tops
    suffix = ["&&", "mv xsim.dir {}".format(xsim_dir.path)]
    compile_log = ctx.actions.declare_file("{}.log".format(ctx.attr.name))
    outputs += [compile_log]
    
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
            {args} 2>&1 > {log} || ( cat {log} && exit 1 ) {suffix}
        """.format(
            script=script,
            vivado_path=VIVADO_PATH,
            command="xelab",
            args=" ".join(args),
            suffix=" ".join(suffix),
            log=compile_log.path,
        ),
    )

    # 2. Test execution script generation
    
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    
    xsim_script_file = ctx.actions.declare_file(
        "{}.xsim.tcl".format(ctx.label.name))
    tcl_script_template = ctx.file.custom_tcl_script or ctx.file.template
    ctx.actions.expand_template(
        output = xsim_script_file,
        template = tcl_script_template,
        substitutions = {
            "{{VCD_FILE}}": "{}.vcd".format(ctx.label.name),
            "{{TOP}}": ctx.attr.top,
        },
    )

    library_symlinks = []
    runfiles_files = [xsim_dir, xsim_script_file, docker_run] + data_files
    
    for name, lib_dir in libraries:
        runfiles_files.append(lib_dir)
        library_symlinks.append("""
    LIB_PATH_VAR=$(rlocation {rloc})
    mkdir -p $(dirname {orig_path})
    ln -sf "$LIB_PATH_VAR" {orig_path}
""".format(rloc=_get_rlocation(lib_dir, ctx), orig_path=lib_dir.path))

    # Docker run command for the test script
    # Note: we use DOCKER_RUN_PLACEHOLDER to be replaced by the actual path at runtime.
    cmd = _script_cmd(
        script_path = "DOCKER_RUN_PLACEHOLDER",
        dir_reference = ".",
        cache_dir = ".vivado_test_cache",
        envs=",".join(["{}={}".format(k, v) for (k,v) in env.items()]),
        mounts=",".join(["{}:{}".format(k, v) for (k,v) in mounts.items()]),
        freeargs=[
            "--net=host",
            "-e", "HOME=/work",
        ],
    )

    ctx.actions.expand_template(
        template = ctx.file._test_template,
        output = executable,
        substitutions = {
            "{{DOCKER_RUN_RLOCATION}}": _get_rlocation(docker_run, ctx),
            "{{XSIM_DIR_RLOCATION}}": _get_rlocation(xsim_dir, ctx),
            "{{XSIM_TCL_RLOCATION}}": _get_rlocation(xsim_script_file, ctx),
            "{{LIBRARY_SYMLINKS}}": "\n".join(library_symlinks),
            "{{CMD}}": cmd,
            "{{VIVADO_PATH}}": VIVADO_PATH,
            "{{XSIM_ARGS}}": " ".join(ctx.attr.args),
            "{{SNAPSHOT_NAME}}": snapshot_name,
        },
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(files = runfiles_files)
                .merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)
                .merge(ctx.attr._script[DefaultInfo].default_runfiles),
        ),
    ]

vivado_test = rule(
    implementation = _vivado_test_impl,
    test = True,
    attrs = DOCKER_RUN_SCRIPT_ATTRS | {
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
        "template": attr.label(
            allow_single_file = [".tcl.template"],
            default=Label("//build/vivado:xsim.tcl.template"),
            doc = "The TCL template to run.",
        ),
        "data": attr.label_list(
            doc = "A list of data targets.",
        ),
        "xelab_relaxed": attr.bool(
            doc = "Relax HDL checks, sometimes needed for Verilog modules",
        ),
        "custom_tcl_script": attr.label(
            doc = "Custom TCL script to run simulation with",
            allow_single_file = True,
            mandatory = False,
        ),
        "xelab_args": attr.string_list(
            doc = "Custom args to elaboration step",
            mandatory = False,
            default = [],
        ),
        "_bash_runfiles": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
        "_test_template": attr.label(
            default = "//internal:vivado_test.sh.tpl",
            allow_single_file = True,
        ),
    },
)
