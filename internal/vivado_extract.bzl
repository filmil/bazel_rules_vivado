"""Rule to extract files out of the Vivado Docker image.

Some Vivado artifacts (for example the `hw_server` binary and the Digilent
cable-driver shared libraries) are needed at runtime but are not meant to be
checked into a repository. Because every `rules_vivado` action already runs
inside the locally provided `xilinx-vivado:<version>` Docker image, those files
are available on the image's filesystem and can be copied out as a normal Bazel
build action. `vivado_extract` does exactly that: it declares one output per
requested file and copies it from the container into the Bazel output tree.
"""

load("//internal:defines.bzl",
    "DOCKER_RUN_SCRIPT_ATTRS",
    "VIVADO_CONFIG_ATTRS",
    _script_cmd = "script_cmd",
    _vivado_config = "vivado_config",
)

def _vivado_extract_impl(ctx):
    """Implementation for the vivado_extract rule.

    Args:
      ctx: The rule context.

    Returns:
      A list of providers with DefaultInfo carrying the extracted files.
    """
    config = _vivado_config(ctx)
    docker_run = ctx.executable._script

    if not ctx.attr.files:
        fail("vivado_extract: `files` must not be empty.")

    out_files = []
    copy_lines = []
    for out_rel, container_path in ctx.attr.files.items():
        out_file = ctx.actions.declare_file(out_rel)
        out_files.append(out_file)

        # Container paths starting with "/" are absolute; otherwise they are
        # resolved relative to the Vivado install path (e.g.
        # /opt/Xilinx/<version>/Vivado).
        src = container_path
        if not src.startswith("/"):
            src = config.vivado_path + "/" + src

        # The output path is relative to the exec root which is the working
        # directory inside the container, so the copy lands in the declared
        # Bazel output. `cp -L` dereferences symlinks; `chmod u+w` guarantees
        # the artifact is writable regardless of the source permissions.
        copy_lines.append("mkdir -p \"$(dirname '{dst}')\"".format(dst = out_file.path))
        copy_lines.append("cp -L '{src}' '{dst}'".format(src = src, dst = out_file.path))
        copy_lines.append("chmod u+w '{dst}'".format(dst = out_file.path))

    # The Docker scratch mount; declared as an output so Bazel knows the action
    # is allowed to create it (mirrors the other Vivado rules).
    cache_dir = ctx.actions.declare_directory("_vivado_extract.cache.{}".format(ctx.label.name))

    # The copy commands run as a single script *inside* the container. Writing
    # them to a file avoids the whitespace/quoting limitations of passing a
    # multi-command string through docker_run.
    inner_script = ctx.actions.declare_file("{}.extract.inner.sh".format(ctx.label.name))
    ctx.actions.write(
        output = inner_script,
        content = "#!/usr/bin/env bash\nset -euo pipefail\n" + "\n".join(copy_lines) + "\n",
        is_executable = True,
    )

    script = _script_cmd(
        docker_run.path,
        out_files[0].path,
        cache_dir.path,
        freeargs = ["--net=host"],
        container = config.container,
    )

    outputs = out_files + [cache_dir]
    ctx.actions.run_shell(
        progress_message = "Vivado extract %d file(s) from %s" % (len(out_files), config.container),
        inputs = [docker_run, inner_script],
        outputs = outputs,
        tools = [docker_run],
        mnemonic = "VivadoExtract",
        command = "{script} bash {inner}".format(script = script, inner = inner_script.path),
    )

    return [DefaultInfo(files = depset(out_files))]

vivado_extract = rule(
    implementation = _vivado_extract_impl,
    doc = "Extracts files from the Vivado Docker image into Bazel outputs.",
    attrs = DOCKER_RUN_SCRIPT_ATTRS | VIVADO_CONFIG_ATTRS | {
        "files": attr.string_dict(
            mandatory = True,
            doc = "Map of output path (relative to this package) to a path " +
                  "inside the Vivado container. A container path starting with " +
                  "'/' is treated as absolute; otherwise it is resolved " +
                  "relative to the Vivado install path (e.g. " +
                  "/opt/Xilinx/<version>/Vivado).",
        ),
    },
)
