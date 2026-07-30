<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Repository rules for a hermetic, Bazel-managed Vivado installation.

`vivado_installation` downloads an AMD/Xilinx unified "SDI" (single-file
download image) installer archive, performs an unattended batch install, and
declares a `vivado_toolchain` that points at the resulting installation.
Together with the `vivado` module extension (see `//:extensions.bzl`) and
the `--//:vivado_mode=hermetic` flag, this gives a per-workspace Vivado
install that Bazel provisions on first use, with no dependency on a host
installation or a Docker image.

The install flow inside the repository rule:

1. Check the persistent install cache (see below); on a hit, only the
   repository's `BUILD.bazel`/`defs.bzl` are regenerated -- no download, no
   install, the fetch completes in seconds.
2. Otherwise, `download_and_extract` the installer archive (any URL Bazel
   supports, including `file:///...` for a locally downloaded archive).
3. Run `xsetup -b ConfigGen` to obtain the full default install
   configuration for the requested product/edition. This is also how the
   exact set of available module names (the "feature menu") is discovered.
4. Rewrite the generated configuration: enable exactly the modules the user
   requested (everything else is disabled), point `Destination` into the
   install cache, and disable desktop integration.
5. Run `xsetup --agree ... --batch Install --config ...` under a file lock,
   then record a `COMPLETE` marker in the cache.
6. Delete the extracted installer payload to reclaim disk space.
7. Write a `BUILD.bazel` declaring a `vivado_toolchain` in `mode = "host"`
   whose `vivado_path` is the absolute path of the cached installation.
   Hermetic mode is host mode with a Bazel-managed install path; no other
   part of the ruleset needs to know the difference.

### The install cache, and why it exists

Bazel refetches an external repository whenever the repository rule's
definition (this file), its attributes, or the output base change -- and a
Vivado reinstall costs ~100 GB of download plus an hour of installing for
an artifact that never changes for given inputs. To make refetches cheap,
the actual installation lives *outside* the repository, in a
content-addressed cache directory inside Bazel's per-user output user
root (by default
`<output_user_root>/rules_vivado/<version>-<key>`, e.g.
`~/.cache/bazel/_bazel_<user>/rules_vivado/...`), keyed by the archive
checksum (or, if absent, by a hash of the URLs and the component
selection). A refetch of the repository finds the cache entry by its
`COMPLETE` marker and skips straight to step 7 above.

Consequences to be aware of:

*   `bazel clean --expunge` does *not* delete the installation: it only
    deletes the workspace's output base, and the cache lives one level
    above, alongside all output bases of the user. Deleting the whole
    Bazel cache (`~/.cache/bazel`) removes the installations with it;
    to reclaim only Vivado's space, remove
    `~/.cache/bazel/_bazel_<user>/rules_vivado`.
*   After manually deleting the cache, force the (cheap) repository fetch
    to be redone with `bazel fetch --force --repo=@vivado_hermetic` (or
    `bazel clean --expunge`), so the repository stops pointing at the
    removed path.
*   Concurrent Bazel servers (e.g. two workspaces using the same cache)
    coordinate through a lock file; the second server waits for the first
    install to finish and then reuses it.

IMPORTANT: this file deliberately load()s nothing. The transitive `.bzl`
digest of a repository rule is part of its identity, so any load edge
would make unrelated edits (e.g. to `toolchain.bzl`) invalidate the
repository and trigger a refetch. Keep it self-contained.

<a id="vivado_hermetic_stub"></a>

## vivado_hermetic_stub

<pre>
load("@rules_vivado//internal:vivado_installation.bzl", "vivado_hermetic_stub")

vivado_hermetic_stub(<a href="#vivado_hermetic_stub-name">name</a>, <a href="#vivado_hermetic_stub-user_repo_name">user_repo_name</a>)
</pre>

Placeholder for @vivado_hermetic when the `vivado` module extension has no `install` tag. Fails with setup instructions if anything actually requests the repository, which only happens under --//:vivado_mode=hermetic.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_hermetic_stub-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_hermetic_stub-user_repo_name"></a>user_repo_name |  -   | String | optional |  `"vivado_hermetic"`  |


<a id="vivado_installation"></a>

## vivado_installation

<pre>
load("@rules_vivado//internal:vivado_installation.bzl", "vivado_installation")

vivado_installation(<a href="#vivado_installation-name">name</a>, <a href="#vivado_installation-edition">edition</a>, <a href="#vivado_installation-eulas">eulas</a>, <a href="#vivado_installation-install_cache">install_cache</a>, <a href="#vivado_installation-install_options">install_options</a>, <a href="#vivado_installation-install_timeout">install_timeout</a>,
                    <a href="#vivado_installation-keep_installer">keep_installer</a>, <a href="#vivado_installation-modules">modules</a>, <a href="#vivado_installation-product">product</a>, <a href="#vivado_installation-sha256">sha256</a>, <a href="#vivado_installation-strip_prefix">strip_prefix</a>, <a href="#vivado_installation-urls">urls</a>, <a href="#vivado_installation-vivado_version">vivado_version</a>)
</pre>

Downloads and batch-installs Vivado into a persistent cache.

Prefer configuring this through the `vivado` module extension
(`@rules_vivado//:extensions.bzl`) rather than instantiating it directly:
the extension creates the `@vivado_hermetic` repository that the built-in
hermetic toolchain registration points at. The extension's `install` tag
accepts the same attributes as this rule.

The installation is large: expect on the order of 100 GB of download, the
same again transiently for the extracted installer payload, plus the
installed size of the selected modules. The extracted payload is deleted
after the install completes. The installation itself lives in a persistent
content-addressed cache (see the module docs), so refetches of this
repository -- after `bazel clean --expunge`, edits to this file, or
attribute changes that do not change the selection -- reuse it instead of
reinstalling.

A fully spelled out example, with every attribute set:

```python
vivado_installation(
    name = "vivado_hermetic",
    # Where to fetch the unified single-file installer archive from. Any
    # Bazel-supported scheme works; AMD downloads require a login, so a
    # local file or an internal mirror is typical.
    urls = ["file:///opt/archives/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar"],
    # Checksum of the archive (output of `sha256sum <archive>`).
    sha256 = "0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0",
    # The archive's top-level directory; autodetected when unset.
    strip_prefix = "FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157",
    # Product and edition, exactly as named in the installer menus.
    product = "Vivado",
    edition = "Vivado ML Standard",
    # Device families to install; everything else is left out. A name
    # matches a menu entry exactly or as an unambiguous substring:
    # "Artix-7" selects the 2025.2 menu entry "Artix-7 FPGAs". The full
    # 2025.2 menu is listed in the `vivado` module extension's docs and
    # in the README ("Selecting installation components"); to list the
    # menu of any other installer version, request a nonexistent module
    # (e.g. `modules = ["?"]`) and read the error message.
    modules = [
        "Artix-7",
        "Zynq-7000",
    ],
    # Post-install steps; usually left empty.
    install_options = ["Acquire or Manage a License Key"],
    # Accepted license agreements (passed to `xsetup --agree`).
    eulas = [
        "XilinxEULA",
        "3rdPartyEULA",
    ],
    # Where the persistent installation lives; "" resolves to
    # $RULES_VIVADO_CACHE, then rules_vivado/ in Bazel's per-user
    # output user root. "none" disables the cache and installs inside
    # the repository.
    install_cache = "",
    # Give the batch install two hours before declaring failure.
    install_timeout = 7200,
    # Keep the extracted installer around for debugging (~100 GB!).
    keep_installer = False,
    # Expected version; also part of the cache key.
    vivado_version = "2025.2",
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_installation-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_installation-edition"></a>edition |  The edition to install, as named in the installer's edition menu. Example: `edition = "Vivado ML Enterprise"` for license holders; the default is the free `"Vivado ML Standard"`.   | String | optional |  `"Vivado ML Standard"`  |
| <a id="vivado_installation-eulas"></a>eulas |  License agreements passed to `xsetup --agree`. By using hermetic mode you confirm that you accept these AMD/Xilinx license terms. Example: `eulas = ["XilinxEULA", "3rdPartyEULA"]` (the default).   | List of strings | optional |  `["XilinxEULA", "3rdPartyEULA"]`  |
| <a id="vivado_installation-install_cache"></a>install_cache |  Root directory of the persistent install cache. When empty, resolves to the `RULES_VIVADO_CACHE` environment variable, then `rules_vivado` inside Bazel's per-user output user root (`~/.cache/bazel/_bazel_<user>/rules_vivado`), tying the installation's lifetime to the user's Bazel cache. The special value `none` disables the cache: the installation then lives inside the repository and is redone on every refetch. Example: `install_cache = "/opt/bazel-vivado-cache"` for a shared machine-wide cache.   | String | optional |  `""`  |
| <a id="vivado_installation-install_options"></a>install_options |  Post-install steps to enable on the `InstallOptions=` line of the install configuration, matched like `modules` entries. When empty, the installer defaults are kept (all steps off). Example: `install_options = ["Acquire or Manage a License Key"]` (the only step the 2025.2 installer offers).   | List of strings | optional |  `[]`  |
| <a id="vivado_installation-install_timeout"></a>install_timeout |  Timeout in seconds for the `xsetup --batch Install` step. Example: `install_timeout = 7200` for two hours; the default is four.   | Integer | optional |  `14400`  |
| <a id="vivado_installation-keep_installer"></a>keep_installer |  Keep the extracted installer payload in the repository instead of deleting it after the install. Example: `keep_installer = True` while debugging a failing install (costs ~100 GB).   | Boolean | optional |  `False`  |
| <a id="vivado_installation-modules"></a>modules |  Installer modules (device families and optional tools) to install. Exactly these modules are enabled; all others are disabled, keeping the install small. A name selects a module menu entry either exactly or as a case-insensitive substring that matches only one entry: `Artix-7` selects the 2025.2 entry `Artix-7 FPGAs`. An unknown name fails with the full menu of available modules (a handy way to discover the menu: request `modules = ["?"]`). When empty, the installer's default selection is installed. After a successful install the full menu is recorded in `@vivado_hermetic//:defs.bzl`. Example: `modules = ["Artix-7", "Zynq-7000"]`.   | List of strings | optional |  `[]`  |
| <a id="vivado_installation-product"></a>product |  The product to install, as named in the installer's product menu. Example: `product = "Vivado"` (other menu entries, e.g. `"Vitis"`, are untested).   | String | optional |  `"Vivado"`  |
| <a id="vivado_installation-sha256"></a>sha256 |  SHA-256 of the installer archive, as printed by `sha256sum <archive>`. Strongly recommended for reproducibility, and used as the install cache key; note that providing it also causes the ~100 GB archive to be stored in Bazel's repository cache. Example: `sha256 = "0f1e...e1f0"`.   | String | optional |  `""`  |
| <a id="vivado_installation-strip_prefix"></a>strip_prefix |  Directory prefix to strip from the extracted archive. Usually unnecessary: the rule finds `xsetup` one level deep on its own. Example: `strip_prefix = "FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157"`.   | String | optional |  `""`  |
| <a id="vivado_installation-urls"></a>urls |  URLs of the AMD/Xilinx unified SDI installer archive (the single-file download, e.g. `FPGAs_AdaptiveSoCs_Unified_SDI_<version>_<build>.tar`). Any Bazel-supported URL scheme works, including `file:///...` for a manually downloaded archive. Example: `urls = ["file:///opt/archives/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar"]`.   | List of strings | required |  |
| <a id="vivado_installation-vivado_version"></a>vivado_version |  Expected Vivado version; part of the install cache key and informational (the installed version is detected from the install layout). Example: `vivado_version = "2025.2"`.   | String | optional |  `"2025.2"`  |


