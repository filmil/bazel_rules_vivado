"""Repository rules for a hermetic, Bazel-managed Vivado installation.

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
"""

# Matches DEFAULT_VIVADO_VERSION in toolchain.bzl; kept separate so that
# this file has no load() edges (see the module docstring).
_DEFAULT_VIVADO_VERSION = "2025.2"

# EULAs that `xsetup --agree` must accept for a batch install to proceed.
DEFAULT_EULAS = [
    "XilinxEULA",
    "3rdPartyEULA",
]

# Desktop-integration settings forced off: they are meaningless inside a
# Bazel-managed installation.
_FORCED_SETTINGS = {
    "CreateDesktopShortcuts": "0",
    "CreateFileAssociation": "0",
    "CreateProgramGroupShortcuts": "0",
    "CreateShortcutsForAllUsers": "0",
}

def _find_xsetup_dir(rctx):
    """Locates the directory containing `xsetup` in the extracted archive."""
    root = rctx.path("installer_sdi")
    if root.get_child("xsetup").exists:
        return root
    for child in root.readdir():
        if child.get_child("xsetup").exists:
            return child
    fail(
        "vivado_installation: could not find `xsetup` in the extracted " +
        "installer archive (looked in {} and its direct subdirectories). ".format(root) +
        "Is the URL really an AMD/Xilinx unified installer (SDI) archive?",
    )

def _config_gen(rctx, xsetup_dir, home):
    """Runs `xsetup -b ConfigGen` and returns the generated config text.

    ConfigGen is non-interactive when the product and edition are passed
    via `-p`/`-e`. One quirk needs care: xsetup writes its logs under
    `$HOME/.Xilinx` (which the caller points into the repository), but the
    generated `install_config.txt` lands in the *real* home directory's
    `~/.Xilinx` (xsetup resolves it via the password database, not $HOME).
    Any pre-existing user config there is preserved: it is moved aside
    before the run and restored afterwards.
    """
    real_home = rctx.os.environ.get("HOME", "")
    real_config = real_home + "/.Xilinx/install_config.txt"
    backup = real_config + ".rules_vivado.bak"
    had_real_config = real_home != "" and rctx.path(real_config).exists
    if had_real_config:
        rctx.execute(["mv", real_config, backup])

    result = rctx.execute(
        [
            "./xsetup",
            "--batch",
            "ConfigGen",
            "--product",
            rctx.attr.product,
            "--edition",
            rctx.attr.edition,
        ],
        environment = {"HOME": home},
        working_directory = str(xsetup_dir),
        timeout = 1800,
    )

    config_text = None
    for candidate in [home + "/.Xilinx/install_config.txt", real_config]:
        if rctx.path(candidate).exists:
            config_text = rctx.read(candidate)
            break

    # Restore the user's own config, and drop the one xsetup just wrote
    # into the real home directory.
    if real_home != "" and rctx.path(real_config).exists:
        rctx.execute(["rm", "-f", real_config])
    if had_real_config:
        rctx.execute(["mv", backup, real_config])

    if config_text == None:
        fail(
            ("vivado_installation: `xsetup -b ConfigGen -p '{}' -e '{}'` " +
             "did not produce an install configuration file (exit code " +
             "{}).\nstdout:\n{}\nstderr:\n{}").format(
                rctx.attr.product,
                rctx.attr.edition,
                result.return_code,
                result.stdout,
                result.stderr,
            ),
        )
    return config_text

def _entry_names(value):
    """Parses the names out of a `Name:0,Other Name:1,...` config value."""
    names = []
    for entry in value.split(","):
        colon = entry.rfind(":")
        name = (entry[:colon] if colon > 0 else entry).strip()
        if name:
            names.append(name)
    return names

def _resolve_selection(requested, names, what):
    """Maps each requested name to the config entry it selects.

    A requested name matches an entry name exactly (case-insensitive), or
    as a case-insensitive substring when that identifies exactly one entry;
    so `Artix-7` selects the menu entry `Artix-7 FPGAs`. Ambiguous or
    unknown names fail with the menu of available names.

    Returns:
      A dict from selected entry name to the requested name.
    """
    by_lower = {n.lower(): n for n in names}
    selected = {}
    for req in requested:
        key = req.strip().lower()
        hit = by_lower.get(key)
        if hit == None:
            matches = [n for n in names if key in n.lower()]
            if len(matches) == 1:
                hit = matches[0]
            elif len(matches) > 1:
                fail(
                    ("vivado_installation: {} '{}' is ambiguous; it " +
                     "matches: {}").format(what, req, ", ".join(matches)),
                )
        if hit == None:
            fail(
                ("vivado_installation: {} '{}' is not offered by this " +
                 "installer.\nAvailable choices:\n  {}").format(
                    what,
                    req,
                    "\n  ".join(names),
                ),
            )
        selected[hit] = req
    return selected

def _select_line(line, prefix, requested, what):
    """Rewrites a `Name:0/1` selection line to enable exactly `requested`.

    Returns:
      A (new_line, names) tuple; names is the full menu offered by the
      installer on this line.
    """
    names = _entry_names(line[len(prefix):])
    selected = _resolve_selection(requested, names, what)
    entries = [n + (":1" if n in selected else ":0") for n in names]
    return prefix + ",".join(entries), names

def _patch_config(rctx, config_text, install_dir):
    """Rewrites the generated install configuration.

    Enables exactly the modules and install options requested via the
    `modules` / `install_options` attributes (all others are disabled),
    points the destination at the install cache, and disables desktop
    integration.

    Returns:
      A (patched_text, available_modules) tuple; available_modules is the
      full menu of module names offered by this installer.
    """
    available = []
    lines = []
    for line in config_text.splitlines():
        key = line.partition("=")[0]
        if line.startswith("Modules="):
            available = _entry_names(line[len("Modules="):])
            if rctx.attr.modules:
                new_line, _ = _select_line(
                    line,
                    "Modules=",
                    rctx.attr.modules,
                    "module",
                )
                lines.append(new_line)
            else:
                lines.append(line)
        elif line.startswith("Destination="):
            lines.append("Destination=" + install_dir)
        elif line.startswith("InstallOptions=") and rctx.attr.install_options:
            new_line, _ = _select_line(
                line,
                "InstallOptions=",
                rctx.attr.install_options,
                "install option",
            )
            lines.append(new_line)
        elif key in _FORCED_SETTINGS:
            lines.append(key + "=" + _FORCED_SETTINGS[key])
        else:
            lines.append(line)
    return "\n".join(lines) + "\n", available

def _install_cache_root(rctx):
    """Resolves the install cache root directory.

    Resolution order: the `install_cache` attribute ("none" disables the
    cache), the `RULES_VIVADO_CACHE` environment variable, then
    `rules_vivado` inside Bazel's *output user root* (the per-user
    directory holding all output bases, e.g.
    `~/.cache/bazel/_bazel_<user>/rules_vivado`). The default ties the
    installation's lifetime to the user's Bazel cache: removing the Bazel
    cache removes the installations too, while `bazel clean --expunge`
    (which only deletes one workspace's output base) leaves them in place.

    Returns:
      The cache root path, or "" when caching is disabled.
    """
    if rctx.attr.install_cache == "none":
        return ""
    if rctx.attr.install_cache:
        return rctx.attr.install_cache
    env_cache = rctx.getenv("RULES_VIVADO_CACHE")
    if env_cache:
        return env_cache

    # This repository lives at <output_base>/external/<repo>; the output
    # user root is the output base's parent.
    output_user_root = rctx.path(".").dirname.dirname.dirname
    return str(output_user_root) + "/rules_vivado"

def _cache_key(rctx):
    """Computes the content-address of this installation in the cache.

    The archive checksum identifies the installation best; without one,
    a hash of the URLs and the component selection is used instead.
    """
    version = rctx.attr.vivado_version or _DEFAULT_VIVADO_VERSION
    if rctx.attr.sha256:
        return version + "-" + rctx.attr.sha256[:16]
    material = "\n".join(
        rctx.attr.urls + [rctx.attr.product, rctx.attr.edition] +
        rctx.attr.modules + rctx.attr.install_options + rctx.attr.eulas,
    )
    rctx.file("cache_key_material.txt", material, executable = False)
    result = rctx.execute(["sha256sum", "cache_key_material.txt"])
    if result.return_code != 0:
        fail("vivado_installation: sha256sum failed: " + result.stderr)
    return version + "-" + result.stdout.split(" ")[0][:16]

def _read_marker(rctx, marker):
    """Returns the COMPLETE marker's text, or None if it does not exist.

    Deliberately uses `cat` rather than repository_ctx file APIs: the
    marker lives outside the repository, and this rule must not register
    a Bazel watch on it (the marker is created *during* the fetch, and a
    watched path changing mid-fetch would immediately invalidate the
    just-fetched repository).
    """
    result = rctx.execute(["cat", marker])
    if result.return_code != 0:
        return None
    return result.stdout

# Runs the batch install into the install cache. Static on purpose: all
# parameters arrive via environment variables, so no .format() escaping of
# bash syntax is needed. The lock serializes concurrent Bazel servers that
# share the cache; whoever loses the race finds the marker and exits.
_INSTALL_SCRIPT = """\
#!/usr/bin/env bash
set -euo pipefail
marker="${CACHE_DIR}/COMPLETE"
dest="${CACHE_DIR}/install"
mkdir -p "${CACHE_DIR}"
exec 9> "${CACHE_DIR}/.lock"
flock 9
if [[ -f "${marker}" ]]; then
  exit 0
fi
# No marker: any content is a leftover partial install. Start clean.
rm -rf "${dest}"
mkdir -p "${dest}"
cd "${XSETUP_DIR}"
HOME="${XHOME}" ./xsetup --agree "${EULAS}" --batch Install \\
    --config "${CONFIG_FILE}"
root=""
for cand in "${dest}"/*/Vivado "${dest}"/Vivado/*; do
  if [[ -x "${cand}/bin/vivado" ]]; then
    root="${cand}"
    break
  fi
done
if [[ -z "${root}" ]]; then
  echo "vivado_installation: the batch install completed but no" \\
       "Vivado/bin/vivado was found under ${dest}" >&2
  exit 1
fi
{
  echo "vivado_root=${root}"
  cat "${MODULES_FILE}"
} > "${marker}.tmp"
mv "${marker}.tmp" "${marker}"
"""

def _version_from_root(vivado_root):
    """Derives the installed version from the Vivado tool directory path.

    Handles both layouts used by AMD installers: `.../<version>/Vivado`
    (2025.1 and later) and `.../Vivado/<version>` (2024.2 and earlier).
    """
    parts = vivado_root.split("/")
    if parts[-1] == "Vivado" and len(parts) >= 2:
        return parts[-2]
    return parts[-1]

_BUILD_TEMPLATE = """\
# Generated by the vivado_installation repository rule. Do not edit.

load("@rules_vivado//internal:toolchain.bzl", "vivado_toolchain")

package(default_visibility = ["//visibility:public"])

# The hermetic Vivado installation behaves exactly like a host install whose
# path happens to live in the rules_vivado install cache, so it reuses host
# mode and the host runner. Selection is gated on --@rules_vivado//:vivado_mode=hermetic
# through the toolchain() registration in @rules_vivado//toolchains.
vivado_toolchain(
    name = "vivado_toolchain",
    mode = "host",
    runner = "@rules_vivado//internal:host_run",
    vivado_path = "{vivado_path}",
    vivado_version = "{vivado_version}",
)
"""

_DEFS_TEMPLATE = """\
# Generated by the vivado_installation repository rule. Do not edit.

# Absolute path of the hermetic Vivado tool directory.
VIVADO_PATH = "{vivado_path}"

# The installed Vivado version.
VIVADO_VERSION = "{vivado_version}"

# The full menu of module names offered by this installer, for reference
# when choosing the `modules` attribute of the `vivado.install` tag.
AVAILABLE_MODULES = {available_modules}
"""

def _emit_repo_files(rctx, marker_text):
    """Generates the repository contents from the COMPLETE marker."""
    vivado_root = None
    modules = []
    for line in marker_text.splitlines():
        if line.startswith("vivado_root="):
            vivado_root = line[len("vivado_root="):]
        elif line.startswith("module="):
            modules.append(line[len("module="):])
    if not vivado_root:
        fail(
            "vivado_installation: the install cache COMPLETE marker is " +
            "malformed (no vivado_root line). Delete the cache entry and " +
            "refetch with: bazel fetch --force --repo=@vivado_hermetic",
        )
    version = _version_from_root(vivado_root)
    rctx.file(
        "BUILD.bazel",
        _BUILD_TEMPLATE.format(
            vivado_path = vivado_root,
            vivado_version = version,
        ),
        executable = False,
    )
    rctx.file(
        "defs.bzl",
        _DEFS_TEMPLATE.format(
            vivado_path = vivado_root,
            vivado_version = version,
            available_modules = repr(modules),
        ),
        executable = False,
    )

def _vivado_installation_impl(rctx):
    if not rctx.attr.urls:
        fail("vivado_installation: the `urls` attribute must not be empty.")

    cache_root = _install_cache_root(rctx)
    if cache_root:
        cache_dir = cache_root + "/" + _cache_key(rctx)
    else:
        # Caching disabled: install inside the repository, restoring the
        # old behavior where `bazel clean --expunge` removes everything.
        cache_dir = str(rctx.path("cache"))
    marker = cache_dir + "/COMPLETE"

    marker_text = _read_marker(rctx, marker)
    if marker_text != None:
        rctx.report_progress("Reusing the cached Vivado installation")
        _emit_repo_files(rctx, marker_text)
        return

    # A writable HOME keeps xsetup's dotfiles (~/.Xilinx) inside the repo.
    home = str(rctx.path("xhome"))
    rctx.execute(["mkdir", "-p", home])

    rctx.report_progress("Downloading and extracting the Vivado installer archive (~100 GB, this takes a while)")
    rctx.download_and_extract(
        url = rctx.attr.urls,
        output = "installer_sdi",
        sha256 = rctx.attr.sha256,
        stripPrefix = rctx.attr.strip_prefix,
    )
    xsetup_dir = _find_xsetup_dir(rctx)

    rctx.report_progress("Generating the Vivado batch install configuration")
    generated_config = _config_gen(rctx, xsetup_dir, home)
    config_text, available = _patch_config(
        rctx,
        generated_config,
        cache_dir + "/install",
    )
    rctx.file("install_config.txt", config_text, executable = False)
    rctx.file(
        "available_modules.txt",
        "".join(["module=" + m + "\n" for m in available]),
        executable = False,
    )
    rctx.file("install_vivado.sh", _INSTALL_SCRIPT, executable = True)

    rctx.report_progress("Running the Vivado batch install (this takes tens of minutes)")
    result = rctx.execute(
        ["./install_vivado.sh"],
        environment = {
            "CACHE_DIR": cache_dir,
            "CONFIG_FILE": str(rctx.path("install_config.txt")),
            "EULAS": ",".join(rctx.attr.eulas),
            "MODULES_FILE": str(rctx.path("available_modules.txt")),
            "XHOME": home,
            "XSETUP_DIR": str(xsetup_dir),
        },
        timeout = rctx.attr.install_timeout,
        quiet = False,
    )
    if result.return_code != 0:
        fail(
            ("vivado_installation: the batch install failed (exit code " +
             "{}).\nstdout:\n{}\nstderr:\n{}").format(
                result.return_code,
                result.stdout,
                result.stderr,
            ),
        )

    if not rctx.attr.keep_installer:
        rctx.report_progress("Deleting the extracted installer payload")
        rctx.delete("installer_sdi")

    marker_text = _read_marker(rctx, marker)
    if marker_text == None:
        fail(
            "vivado_installation: the batch install completed but the " +
            "cache marker {} was not written.".format(marker),
        )
    _emit_repo_files(rctx, marker_text)

vivado_installation = repository_rule(
    implementation = _vivado_installation_impl,
    doc = """Downloads and batch-installs Vivado into a persistent cache.

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
    # "Artix-7" selects the 2025.2 menu entry "Artix-7 FPGAs".
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
""",
    attrs = {
        "urls": attr.string_list(
            mandatory = True,
            doc = "URLs of the AMD/Xilinx unified SDI installer archive " +
                  "(the single-file download, e.g. " +
                  "`FPGAs_AdaptiveSoCs_Unified_SDI_<version>_<build>.tar`). " +
                  "Any Bazel-supported URL scheme works, including " +
                  "`file:///...` for a manually downloaded archive. " +
                  "Example: `urls = [\"file:///opt/archives/" +
                  "FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar\"]`.",
        ),
        "sha256": attr.string(
            doc = "SHA-256 of the installer archive, as printed by " +
                  "`sha256sum <archive>`. Strongly recommended for " +
                  "reproducibility, and used as the install cache key; " +
                  "note that providing it also causes the ~100 GB archive " +
                  "to be stored in Bazel's repository cache. Example: " +
                  "`sha256 = \"0f1e...e1f0\"`.",
        ),
        "strip_prefix": attr.string(
            doc = "Directory prefix to strip from the extracted archive. " +
                  "Usually unnecessary: the rule finds `xsetup` one level " +
                  "deep on its own. Example: `strip_prefix = " +
                  "\"FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157\"`.",
        ),
        "product": attr.string(
            default = "Vivado",
            doc = "The product to install, as named in the installer's " +
                  "product menu. Example: `product = \"Vivado\"` (other " +
                  "menu entries, e.g. `\"Vitis\"`, are untested).",
        ),
        "edition": attr.string(
            default = "Vivado ML Standard",
            doc = "The edition to install, as named in the installer's " +
                  "edition menu. Example: `edition = \"Vivado ML " +
                  "Enterprise\"` for license holders; the default is the " +
                  "free `\"Vivado ML Standard\"`.",
        ),
        "modules": attr.string_list(
            doc = "Installer modules (device families and optional tools) " +
                  "to install. Exactly these modules are enabled; all " +
                  "others are disabled, keeping the install small. A name " +
                  "selects a module menu entry either exactly or as a " +
                  "case-insensitive substring that matches only one entry: " +
                  "`Artix-7` selects the 2025.2 entry `Artix-7 FPGAs`. An " +
                  "unknown name fails with the full menu of available " +
                  "modules (a handy way to discover the menu: request " +
                  "`modules = [\"?\"]`). When empty, the installer's " +
                  "default selection is installed. After a successful " +
                  "install the full menu is recorded in " +
                  "`@vivado_hermetic//:defs.bzl`. Example: `modules = " +
                  "[\"Artix-7\", \"Zynq-7000\"]`.",
        ),
        "install_options": attr.string_list(
            doc = "Post-install steps to enable on the `InstallOptions=` " +
                  "line of the install configuration, matched like " +
                  "`modules` entries. When empty, the installer defaults " +
                  "are kept (all steps off). Example: `install_options = " +
                  "[\"Acquire or Manage a License Key\"]` (the only step " +
                  "the 2025.2 installer offers).",
        ),
        "eulas": attr.string_list(
            default = DEFAULT_EULAS,
            doc = "License agreements passed to `xsetup --agree`. By using " +
                  "hermetic mode you confirm that you accept these AMD/" +
                  "Xilinx license terms. Example: `eulas = " +
                  "[\"XilinxEULA\", \"3rdPartyEULA\"]` (the default).",
        ),
        "install_cache": attr.string(
            doc = "Root directory of the persistent install cache. When " +
                  "empty, resolves to the `RULES_VIVADO_CACHE` " +
                  "environment variable, then `rules_vivado` inside " +
                  "Bazel's per-user output user root " +
                  "(`~/.cache/bazel/_bazel_<user>/rules_vivado`), tying " +
                  "the installation's lifetime to the user's Bazel " +
                  "cache. The special value `none` disables the cache: " +
                  "the installation then lives inside the repository and " +
                  "is redone on every refetch. Example: `install_cache " +
                  "= \"/opt/bazel-vivado-cache\"` for a shared machine-" +
                  "wide cache.",
        ),
        "install_timeout": attr.int(
            default = 4 * 60 * 60,
            doc = "Timeout in seconds for the `xsetup --batch Install` " +
                  "step. Example: `install_timeout = 7200` for two hours; " +
                  "the default is four.",
        ),
        "keep_installer": attr.bool(
            default = False,
            doc = "Keep the extracted installer payload in the repository " +
                  "instead of deleting it after the install. Example: " +
                  "`keep_installer = True` while debugging a failing " +
                  "install (costs ~100 GB).",
        ),
        "vivado_version": attr.string(
            default = _DEFAULT_VIVADO_VERSION,
            doc = "Expected Vivado version; part of the install cache key " +
                  "and informational (the installed version is detected " +
                  "from the install layout). Example: `vivado_version = " +
                  "\"2025.2\"`.",
        ),
    },
)

def _vivado_hermetic_stub_impl(rctx):
    fail(
        "The @{} repository was requested (--@rules_vivado//:vivado_mode=".format(rctx.attr.user_repo_name) +
        "hermetic is in effect), but no hermetic Vivado installation is " +
        "configured. Add this to your MODULE.bazel:\n\n" +
        "    vivado = use_extension(\"@rules_vivado//:extensions.bzl\", \"vivado\")\n" +
        "    vivado.install(\n" +
        "        urls = [\"file:///path/to/FPGAs_AdaptiveSoCs_Unified_SDI_<version>.tar\"],\n" +
        "        modules = [\"Artix-7\"],\n" +
        "    )\n",
    )

vivado_hermetic_stub = repository_rule(
    implementation = _vivado_hermetic_stub_impl,
    doc = "Placeholder for @vivado_hermetic when the `vivado` module " +
          "extension has no `install` tag. Fails with setup instructions " +
          "if anything actually requests the repository, which only " +
          "happens under --//:vivado_mode=hermetic.",
    attrs = {
        "user_repo_name": attr.string(default = "vivado_hermetic"),
    },
)
