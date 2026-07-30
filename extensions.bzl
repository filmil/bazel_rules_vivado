"""Module extensions for rules_vivado.

The `vivado` extension provisions a hermetic, Bazel-managed Vivado
installation (the `@vivado_hermetic` repository), used when building with
`--@rules_vivado//:vivado_mode=hermetic`. Configure it in the root module:

```python
vivado = use_extension("@rules_vivado//:extensions.bzl", "vivado")
vivado.install(
    urls = ["https://your.mirror/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157.tar"],
    sha256 = "...",
    # A name selects an installer menu entry exactly or as an unambiguous
    # substring: "Artix-7" selects the 2025.2 entry "Artix-7 FPGAs".
    modules = [
        "Artix-7",
        "Zynq-7000",
    ],
)
```

and select the mode in `.bazelrc`:

```
build --@rules_vivado//:vivado_mode=hermetic
```

All attributes of the `install` tag mirror the attributes of the
`vivado_installation` repository rule
(`@rules_vivado//internal:vivado_installation.bzl`); see there for the
full per-attribute documentation and examples.

The repository is only fetched (that is: the ~100 GB installer is only
downloaded and installed) when hermetic mode is actually selected; in
docker/host mode the extension is inert. Without an `install` tag the
extension creates a stub that fails with setup instructions if hermetic
mode is requested.
"""

load(
    "//internal:vivado_installation.bzl",
    "vivado_hermetic_stub",
    "vivado_installation",
)

_install = tag_class(
    doc = "Configures the hermetic Vivado installation. Only the root " +
          "module's tag is honored, and at most one may be present.",
    attrs = {
        "urls": attr.string_list(
            mandatory = True,
            doc = "URLs of the AMD/Xilinx unified SDI installer archive; " +
                  "`file:///...` URLs work for a manually downloaded copy. " +
                  "Example: `urls = [\"file:///opt/archives/" +
                  "FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar\"]`.",
        ),
        "sha256": attr.string(
            doc = "SHA-256 of the installer archive (`sha256sum " +
                  "<archive>`). Example: `sha256 = \"0f1e...e1f0\"`.",
        ),
        "strip_prefix": attr.string(
            doc = "Directory prefix to strip from the extracted archive " +
                  "(usually autodetected). Example: `strip_prefix = " +
                  "\"FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157\"`.",
        ),
        "product": attr.string(
            default = "Vivado",
            doc = "Installer product menu entry to install. Example: " +
                  "`product = \"Vivado\"`.",
        ),
        "edition": attr.string(
            default = "Vivado ML Standard",
            doc = "Installer edition menu entry to install. Example: " +
                  "`edition = \"Vivado ML Enterprise\"`.",
        ),
        "modules": attr.string_list(
            doc = "Installer modules (device families, optional tools) to " +
                  "enable; everything else is disabled. Names match menu " +
                  "entries exactly or as an unambiguous substring. " +
                  "Example: `modules = [\"Artix-7\", \"Zynq-7000\"]`.",
        ),
        "install_options": attr.string_list(
            doc = "Post-install steps to enable on the InstallOptions= " +
                  "line, matched like `modules`. Example: " +
                  "`install_options = [\"Acquire or Manage a License " +
                  "Key\"]`.",
        ),
        "eulas": attr.string_list(
            default = [
                "XilinxEULA",
                "3rdPartyEULA",
            ],
            doc = "License agreements passed to `xsetup --agree`; using " +
                  "hermetic mode confirms you accept them. Example: " +
                  "`eulas = [\"XilinxEULA\", \"3rdPartyEULA\"]`.",
        ),
        "install_cache": attr.string(
            doc = "Root of the persistent install cache; \"\" resolves " +
                  "to $RULES_VIVADO_CACHE, then `rules_vivado` in " +
                  "Bazel's per-user output user root; \"none\" disables " +
                  "caching. Example: `install_cache = " +
                  "\"/opt/bazel-vivado-cache\"`.",
        ),
        "install_timeout": attr.int(
            default = 4 * 60 * 60,
            doc = "Timeout in seconds for the batch install step. " +
                  "Example: `install_timeout = 7200`.",
        ),
        "keep_installer": attr.bool(
            default = False,
            doc = "Keep the extracted installer payload (debugging only; " +
                  "~100 GB). Example: `keep_installer = True`.",
        ),
        "vivado_version": attr.string(
            doc = "Expected Vivado version (informational). Example: " +
                  "`vivado_version = \"2025.2\"`.",
        ),
    },
)

def _vivado_impl(mctx):
    tag = None
    for mod in mctx.modules:
        for t in mod.tags.install:
            if not mod.is_root:
                # A dependency cannot decide to install a ~100 GB toolchain
                # on the root module's behalf.
                print(
                    ("rules_vivado: ignoring vivado.install tag from " +
                     "non-root module '{}'; only the root module may " +
                     "configure the hermetic Vivado installation.").format(mod.name),
                )  # buildifier: disable=print
                continue
            if tag != None:
                fail("rules_vivado: at most one vivado.install tag is allowed.")
            tag = t

    if tag == None:
        vivado_hermetic_stub(name = "vivado_hermetic")
    else:
        vivado_installation(
            name = "vivado_hermetic",
            urls = tag.urls,
            sha256 = tag.sha256,
            strip_prefix = tag.strip_prefix,
            product = tag.product,
            edition = tag.edition,
            modules = tag.modules,
            install_options = tag.install_options,
            eulas = tag.eulas,
            install_cache = tag.install_cache,
            install_timeout = tag.install_timeout,
            keep_installer = tag.keep_installer,
            vivado_version = tag.vivado_version or "2025.2",
        )

vivado = module_extension(
    implementation = _vivado_impl,
    tag_classes = {
        "install": _install,
    },
    doc = "Provisions the hermetic Vivado installation repository " +
          "`@vivado_hermetic`. See the module-level docs.",
)
