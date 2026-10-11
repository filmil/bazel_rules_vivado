<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Module extensions for rules_vivado.

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
    #
    # The 2025.2 installer offers these modules -- device families:
    #   "Spartan-7 FPGAs", "Spartan UltraScale+",
    #   "Artix-7 FPGAs", "Artix UltraScale+ FPGAs",
    #   "Kintex-7 FPGAs", "Kintex UltraScale FPGAs",
    #   "Kintex UltraScale+ FPGAs",
    #   "Virtex UltraScale+ FPGAs", "Virtex UltraScale+ HBM FPGAs",
    #   "Virtex UltraScale+ 58G FPGAs",
    #   "Zynq-7000 All Programmable SoC", "Zynq UltraScale+ MPSoCs",
    #   Versal parts (offered individually): "xcv80", "xcvm1102",
    #   "xcve2002", "xcve2102", "xcve2202", "xcve2302",
    #   "Versal RF Series ES1",
    #   "Install devices for Alveo and edge acceleration platforms",
    #   "Install Devices for Kria SOMs and Starter Kits"
    # and optional tools:
    #   "DocNav", "Vitis Model Composer(A toolbox for Simulink)",
    #   "Vitis Embedded Development", "Vitis Networking P4",
    #   "Power Design Manager (PDM)"
    #
    # Other installer versions differ. To list the menu of *your*
    # archive, request a nonexistent module (e.g. `modules = ["?"]`):
    # the fetch fails with the full menu in the error message. After a
    # successful install the menu is also recorded as AVAILABLE_MODULES
    # in @vivado_hermetic//:defs.bzl.
    modules = [
        "Artix-7",
        "Zynq-7000",
    ],
)
```

Hermetic mode is the default since 4.0.0. To say so explicitly, or to
switch back to it from another mode, put this in `.bazelrc`:

```
build --@rules_vivado//:vivado_mode=hermetic
```

Because the archive's path usually differs per machine while
`MODULE.bazel` is committed and shared, `VIVADO_INSTALLER_URL` overrides
whatever the module declared:

```
# user.bazelrc, which is gitignored
common --repo_env=VIVADO_INSTALLER_URL=file:///home/me/Downloads/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar
```

The committed `sha256` still applies, so redirecting to a mirror of the
same archive is safe and a substituted one is caught; use
`VIVADO_INSTALLER_SHA256` alongside it when pointing at a genuinely
different archive.

All attributes of the `install` tag mirror the attributes of the
`vivado_installation` repository rule
(`@rules_vivado//internal:vivado_installation.bzl`); see there for the
full per-attribute documentation and examples.

The repository is only fetched (that is: the ~100 GB installer is only
downloaded and installed) when hermetic mode is actually selected; in
docker/host mode the extension is inert. Without an `install` tag the
extension creates a stub that fails with setup instructions if hermetic
mode is requested.

<a id="vivado"></a>

## vivado

<pre>
vivado = use_extension("@rules_vivado//:extensions.bzl", "vivado")
vivado.install(<a href="#vivado.install-edition">edition</a>, <a href="#vivado.install-eulas">eulas</a>, <a href="#vivado.install-install_cache">install_cache</a>, <a href="#vivado.install-install_options">install_options</a>, <a href="#vivado.install-install_timeout">install_timeout</a>, <a href="#vivado.install-keep_installer">keep_installer</a>,
               <a href="#vivado.install-modules">modules</a>, <a href="#vivado.install-product">product</a>, <a href="#vivado.install-sha256">sha256</a>, <a href="#vivado.install-strip_prefix">strip_prefix</a>, <a href="#vivado.install-urls">urls</a>, <a href="#vivado.install-vivado_version">vivado_version</a>)
</pre>

Provisions the hermetic Vivado installation repository `@vivado_hermetic`. See the module-level docs.


**TAG CLASSES**

<a id="vivado.install"></a>

### install

Configures the hermetic Vivado installation. Only the root module's tag is honored, and at most one may be present.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado.install-edition"></a>edition |  Installer edition menu entry to install. Example: `edition = "Vivado ML Enterprise"`.   | String | optional |  `"Vivado ML Standard"`  |
| <a id="vivado.install-eulas"></a>eulas |  License agreements passed to `xsetup --agree`; using hermetic mode confirms you accept them. Example: `eulas = ["XilinxEULA", "3rdPartyEULA"]`.   | List of strings | optional |  `["XilinxEULA", "3rdPartyEULA"]`  |
| <a id="vivado.install-install_cache"></a>install_cache |  Root of the persistent install cache; "" resolves to $RULES_VIVADO_CACHE, then `rules_vivado` in Bazel's per-user output user root; "none" disables caching. Example: `install_cache = "/opt/bazel-vivado-cache"`.   | String | optional |  `""`  |
| <a id="vivado.install-install_options"></a>install_options |  Post-install steps to enable on the InstallOptions= line, matched like `modules`. Example: `install_options = ["Acquire or Manage a License Key"]`.   | List of strings | optional |  `[]`  |
| <a id="vivado.install-install_timeout"></a>install_timeout |  Timeout in seconds for the batch install step. Example: `install_timeout = 7200`.   | Integer | optional |  `14400`  |
| <a id="vivado.install-keep_installer"></a>keep_installer |  Keep the extracted installer payload (debugging only; ~100 GB). Example: `keep_installer = True`.   | Boolean | optional |  `False`  |
| <a id="vivado.install-modules"></a>modules |  Installer modules (device families, optional tools) to enable; everything else is disabled. Names match menu entries exactly or as an unambiguous substring. Example: `modules = ["Artix-7", "Zynq-7000"]`.   | List of strings | optional |  `[]`  |
| <a id="vivado.install-product"></a>product |  Installer product menu entry to install. Example: `product = "Vivado"`.   | String | optional |  `"Vivado"`  |
| <a id="vivado.install-sha256"></a>sha256 |  SHA-256 of the installer archive (`sha256sum <archive>`). Still applies when `VIVADO_INSTALLER_URL` redirects to a mirror, so a substituted archive is caught; override it with `VIVADO_INSTALLER_SHA256` when pointing at a genuinely different one. Example: `sha256 = "0f1e...e1f0"`.   | String | optional |  `""`  |
| <a id="vivado.install-strip_prefix"></a>strip_prefix |  Directory prefix to strip from the extracted archive (usually autodetected). Example: `strip_prefix = "FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157"`.   | String | optional |  `""`  |
| <a id="vivado.install-urls"></a>urls |  URLs of the AMD/Xilinx unified SDI installer archive; `file:///...` URLs work for a manually downloaded copy. Example: `urls = ["file:///opt/archives/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar"]`. The `VIVADO_INSTALLER_URL` environment variable overrides this at fetch time, so a path that differs per machine does not have to be committed.   | List of strings | optional |  `[]`  |
| <a id="vivado.install-vivado_version"></a>vivado_version |  Expected Vivado version (informational). Example: `vivado_version = "2025.2"`.   | String | optional |  `""`  |


