# The Vivado toolchain: execution modes in detail

All rules in this repository invoke Vivado through a Bazel toolchain. The
toolchain decides *how* Vivado runs; the rules themselves are agnostic to it.
The following modes are available:

| Mode | What it does | Requirements |
| :--- | :--- | :--- |
| `docker` (default) | Runs Vivado inside the local `xilinx-vivado:<version>` Docker image. | Docker, plus the locally built Vivado image (see prerequisites). |
| `host` | Runs a Vivado installed on the host machine directly. | A local Vivado installation. |
| `hermetic` | Downloads the AMD/Xilinx installer and batch-installs Vivado into a Bazel-managed external repository, then runs it from there. | The installer archive URL (see below); about 300 GB of transient disk space, and Bazel 9.2.0 or later for a `file://` URL. |
| `custom` | Matches no built-in toolchain; a toolchain registered by you or one of your dependency modules is selected instead. | A registered `vivado_toolchain` (see below). |

## Selecting the mode

The mode is selected with the `--@rules_vivado//:vivado_mode` build setting
flag. To use a host Vivado installation, add this to your project's
`.bazelrc`:

```
# Use the Vivado installed on this machine instead of the Docker container.
build --@rules_vivado//:vivado_mode=host
```

(Adjust the repo name if you imported the module under a different name.)
Omitting the flag, or setting it to `docker`, keeps the default dockerized
behavior.

## Configuring versions and paths

Three additional flags adjust the configuration in either mode:

| Flag | Meaning | Default |
| :--- | :--- | :--- |
| `--@rules_vivado//internal:vivado_version` | The Vivado version. | `2025.2` |
| `--@rules_vivado//internal:vivado_path` | The Vivado install path: inside the container in `docker` mode, on the host filesystem in `host` mode. | `/opt/Xilinx/<version>/Vivado` |
| `--@rules_vivado//internal:vivado_container` | The Docker image (`docker` mode only). | `xilinx-vivado:<version>` |

For example, to use a host Vivado 2024.2 installed under `/tools/Xilinx`:

```
build --@rules_vivado//:vivado_mode=host
build --@rules_vivado//internal:vivado_version=2024.2
build --@rules_vivado//internal:vivado_path=/tools/Xilinx/Vivado/2024.2
```

## Hermetic mode: a Bazel-managed Vivado installation

In `hermetic` mode, Bazel itself downloads the AMD/Xilinx unified installer
(the "SDI" single-file download from the
[AMD download site](https://www.xilinx.com/support/download.html)) and
performs an unattended batch install into an external repository
(`@vivado_hermetic`). Builds then use that installation: no host Vivado, no
Docker image, and every machine building the same workspace gets the same
Vivado, provisioned on first use.

If you are setting this up for the first time, or writing down what a
new person on the project has to do,
[hermetic-quickstart.md](hermetic-quickstart.md) walks through it one
step at a time: what to download, what goes in `MODULE.bazel`, what
goes in your own `user.bazelrc`, and what the first build costs. The
rest of this section is the reference behind it.

Configure it in your `MODULE.bazel` through the `vivado` module extension:

```python
vivado = use_extension("@rules_vivado//:extensions.bzl", "vivado")
vivado.install(
    # Any Bazel-supported URL scheme works. AMD downloads require a
    # login, so typically you download the archive once and serve it
    # from a file:// path or an internal mirror.
    urls = ["file:///opt/archives/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157.tar"],
    sha256 = "...",  # Optional but recommended; see the caveats below.
    # The device families (and optional tools) to install; everything
    # not listed here is excluded, keeping the installation small. See
    # "Selecting installation components" below for the full menu of
    # names that can appear here and how they are matched.
    modules = [
        "Artix-7",
        "Zynq-7000",
    ],
)
```

and select the mode in your `.bazelrc`:

```
build --@rules_vivado//:vivado_mode=hermetic
```

A ready-made example lives in this repository:
[`//build/tests/vivado:blinky_synth_hermetic_test`](../build/tests/vivado/BUILD.bazel)
synthesizes a small design with the hermetic toolchain. It forces
`vivado_mode=hermetic` through a configuration transition (see
[`hermetic_build_test.bzl`](../build/tests/vivado/hermetic_build_test.bzl),
which you can copy into your own workspace), and it is tagged `manual`
because a cold run performs the full ~100 GB installation:

```sh
bazel test //build/tests/vivado:blinky_synth_hermetic_test
```

The `install` tag accepts, most importantly (see
`internal/vivado_installation.bzl` for the full list, with examples for
every attribute):

| Attribute | Meaning | Default |
| :--- | :--- | :--- |
| `urls` | Installer archive URLs (mandatory). | |
| `sha256` | Archive checksum. | unset |
| `product` | Installer product menu entry. | `Vivado` |
| `edition` | Installer edition menu entry. | `Vivado ML Standard` |
| `modules` | Device families / tools to install (see below). | installer defaults |
| `install_options` | Post-install steps (see below). | installer defaults |
| `eulas` | Agreements passed to `xsetup --agree`. | `XilinxEULA,3rdPartyEULA` |
| `install_timeout` | Batch install timeout, seconds. | 4 hours |

### Selecting installation components

The AMD installer organizes an installation as a *product* (`Vivado`),
an *edition* (`Vivado ML Standard` or `Vivado ML Enterprise`), and a menu
of *modules*: device families and optional tools that can each be switched
on or off. The `modules` attribute lists the modules to install; everything
not listed is excluded, which is what keeps a hermetic install small. Rules
for writing the list:

*   A name selects a menu entry either **exactly** or as a
    **case-insensitive substring** that matches exactly one entry. So
    `Artix-7` selects the entry `Artix-7 FPGAs`, and `zynq-7000` selects
    `Zynq-7000 All Programmable SoC`. An ambiguous substring (for example
    `UltraScale`, which matches several families) fails with the list of
    candidate entries; an unknown name fails with the whole menu.
*   Pick the device families that cover the FPGA parts you build for: for
    example `part = "xc7a200tfbg484-2"` (an Artix-7 part) needs the
    `Artix-7 FPGAs` module.
*   An empty `modules` list installs the installer's *default* selection,
    which is large; prefer an explicit list.
*   The menu differs per installer version. To discover it for your
    archive, request a nonexistent module (e.g. `modules = ["?"]`) and
    read the failure message, which prints the full menu; or after a
    successful install read `@vivado_hermetic//:defs.bzl`, where the menu
    is recorded as `AVAILABLE_MODULES`.

For reference, the 2025.2 `FPGAs_AdaptiveSoCs_Unified_SDI` installer
(product `Vivado`, edition `Vivado ML Standard`) offers these modules --
device families:

*   `Spartan-7 FPGAs`, `Spartan UltraScale+`
*   `Artix-7 FPGAs`, `Artix UltraScale+ FPGAs`
*   `Kintex-7 FPGAs`, `Kintex UltraScale FPGAs`, `Kintex UltraScale+ FPGAs`
*   `Virtex UltraScale+ FPGAs`, `Virtex UltraScale+ HBM FPGAs`,
    `Virtex UltraScale+ 58G FPGAs`
*   `Zynq-7000 All Programmable SoC`, `Zynq UltraScale+ MPSoCs`
*   Versal parts, offered individually: `xcv80`, `xcvm1102`, `xcve2002`,
    `xcve2102`, `xcve2202`, `xcve2302`, `Versal RF Series ES1`
*   `Install devices for Alveo and edge acceleration platforms`,
    `Install Devices for Kria SOMs and Starter Kits`

and optional tools:

*   `DocNav` (documentation navigator; on by default)
*   `Vitis Model Composer(A toolbox for Simulink)` (on by default)
*   `Vitis Embedded Development`, `Vitis Networking P4`,
    `Power Design Manager (PDM)`

The `install_options` attribute works the same way, but for the
installer's post-install steps; 2025.2 offers only
`Acquire or Manage a License Key`, off by default. Leave the attribute
empty to keep the defaults.

Caveats worth knowing:

*   **Scale.** The installer archive is on the order of 100 GB; the first
    hermetic build downloads it, extracts it (another ~100 GB, deleted after
    the install), and installs the selected modules. Subsequent builds
    reuse the repository. See "What a cold install actually costs" below
    for measured numbers.
*   **Repository cache.** Bazel stores the archive in its repository
    cache whether or not `sha256` is set. Measured on Bazel 9.2.0 with
    no `sha256`: the archive appeared under
    `<repository_cache>/content_addressable/sha256/<hash>/file` at the
    archive's exact byte size, in a directory named with the archive's
    own checksum, which Bazel computed itself. Budget for that copy in
    either case. Since it costs the same either way, setting `sha256` is
    close to free and buys integrity checking.
*   **Bazel 9.2.0 or later is required** if the archive is named by a
    `file://` URL, which is the usual way to serve it. Bazel 9.1.0
    crashes partway through the fetch:
    `NullPointerException: Cannot invoke "String.equals(Object)" because
    the return value of "java.net.URI.getHost()" is null`, thrown from
    `ProgressInputStream.reportProgress`. `URI.getHost()` is `null` for a
    `file://` URL, and the download progress reporter calls `equals` on
    it. The crash arrives on the first progress report, tens of megabytes
    into the transfer, so a small archive may never reach it and a 100 GB
    one always does.
*   **Licensing.** By using hermetic mode you accept the AMD/Xilinx EULAs
    listed in the `eulas` attribute, exactly as if you had clicked through
    the installer. Only the root module may configure the installation.
*   **The installation survives `bazel clean --expunge`**: it lives in the
    persistent install cache described below, not in the external
    repository, precisely so that refetches do not redo the ~100 GB
    install.
*   Under the hood hermetic mode is host mode whose `vivado_path` points
    at the cached installation; the "Notes on host mode" below apply to
    it.

### What a cold install actually costs

Measured once, end to end, on a single machine: 8 core x86-64, 62 GB
RAM, `modules = ["Artix-7"]`, Bazel 9.2.0, Vivado 2025.2.

The storage matters more than anything else here, so it is stated
first: the installer archive and the Bazel output base were on the same
volume, an LVM logical volume on a RAID-1 pair of 7200 RPM HGST
HUS726020AL spinning disks. RAID-1 writes every block to both members,
so write bandwidth is that of one disk. Anyone running this on NVMe
should expect the copying phases to be several times faster, and should
treat the timings below as an upper bound rather than a typical result.

| Phase | Reached at | Duration |
| :--- | ---: | ---: |
| Copy the archive, write it to the repository cache, unpack it | 1h 52m | 1h 52m |
| Batch install starts | 2h 01m | |
| Install finishes, `COMPLETE` written | 2h 14m | 13m |
| First simulation output | 2h 16m | |

The shape of that is worth stating plainly, because it is the opposite
of what the wording above implies. **The install is not the expensive
part.** It took 13 minutes. The other 112 minutes went entirely on
moving the archive around: copying it into the output base, writing a
second copy into the repository cache, and unpacking it.

Sizes measured in the same run:

| Thing | Size |
| :--- | ---: |
| Installer archive | 95.7 GiB (102739568640 bytes) |
| Copy in the repository cache | 97.3 GiB |
| Unpacked installer tree | 95.7 GiB, deleted after the install |
| Installed Vivado, `Artix-7` only | 51.2 GiB |
| **Peak free space consumed** | **about 291 GB** |

So the `~200 GB of transient disk space` figure in the mode table is
low. Three copies of a 100 GB archive exist at once at the peak, before
the archive is deleted. Plan for 300 GB free, plus the installed tree.

These are single-run numbers from one machine, not a benchmark. The
bottleneck is copying rather than compute: the install phase used
several cores and finished in 13 minutes, while the three sequential
passes over ~100 GB took nearly two hours on rotational storage. A
machine with the archive on a separate device from the output base, or
on flash, should do markedly better.

### Reinstalls and the install cache

Bazel refetches an external repository whenever the repository rule's
inputs change: its attributes (the `install` tag values), the `.bzl` file
implementing it, the output base (`bazel clean --expunge`), or tracked
environment variables. For most repositories a refetch is cheap; for a
Vivado installation it would mean re-downloading and re-installing ~100 GB
for a result that is bit-for-bit the same. Two measures keep this from
happening:

*   The actual installation lives *outside* the workspace's output base,
    in a content-addressed **install cache** inside Bazel's per-user
    output user root: by default
    `~/.cache/bazel/_bazel_<user>/rules_vivado/<version>-<key>`, where
    `<key>` is the archive `sha256` (or, if unset, a hash of the URLs and
    the component selection). This ties the installation's lifetime to
    the user's Bazel cache -- all workspaces of the user share it, and
    deleting the Bazel cache deletes it -- while `bazel clean --expunge`
    (which only removes one workspace's output base) leaves it intact. A
    repository refetch that finds the cache entry's `COMPLETE` marker
    skips the download and install entirely and merely regenerates the
    repository's two small files -- it completes in seconds. Reinstalls
    therefore only happen when the *selection* actually changes
    (different archive, modules, edition, ...), which creates a new cache
    entry.
*   `internal/vivado_installation.bzl` deliberately `load()`s nothing, so
    edits to the rest of the ruleset never invalidate the repository in
    the first place.

Knobs and consequences:

*   The cache root is, in order: the `install_cache` attribute of the
    `install` tag, the `RULES_VIVADO_CACHE` environment variable, then
    `rules_vivado` inside Bazel's output user root. Point it at a shared
    location (e.g. `/opt/bazel-vivado-cache`) to share one installation
    across users on a machine; concurrent installs coordinate through a
    lock file.
*   `install_cache = "none"` restores the uncached behavior: the
    installation lives inside the repository and every refetch redoes it.
*   To reclaim the disk space without touching the rest of the Bazel
    cache, delete the cache directory yourself
    (`rm -rf ~/.cache/bazel/_bazel_$USER/rules_vivado`); afterwards run
    `bazel fetch --force --repo=@vivado_hermetic` (or
    `bazel clean --expunge`) so the repository notices and reinstalls on
    the next hermetic build.
*   Old cache entries (from previous selections) are not garbage
    collected; prune them manually when disk space matters.

## Defining a custom toolchain

If the flags are not enough (for example, you want the mode to depend on the
platform, or you maintain several Vivado installations), you can declare and
register your own toolchain instance instead:

```python
# BUILD.bazel
load("@rules_vivado//build/vivado:rules.bzl", "vivado_toolchain")

vivado_toolchain(
    name = "my_host_vivado",
    mode = "host",
    vivado_version = "2024.2",
    vivado_path = "/tools/Xilinx/Vivado/2024.2",
    runner = "@rules_vivado//internal:host_run",
)

toolchain(
    name = "my_host_vivado_toolchain",
    toolchain = ":my_host_vivado",
    toolchain_type = "@rules_vivado//toolchains:toolchain_type",
)
```

```python
# MODULE.bazel: user-registered toolchains take precedence over the ones
# registered by rules_vivado itself.
register_toolchains("//:my_host_vivado_toolchain")
```

The `runner` attribute is the executable that every generated Vivado command
line is prefixed with. The two built-in runners accept the same command line
flags and are therefore interchangeable:

*   `@rules_bid//build:docker_run` wraps the command in `docker run`;
*   `@rules_vivado//internal:host_run` ignores the docker-specific flags and
    executes the command directly on the host.

A custom `runner` may be supplied instead: any executable that accepts the
same command line contract (flags first, the Vivado command tail after) can
take their place -- for example a podman wrapper, or a script that runs the
command on a remote build machine. Set `mode` to whichever of the two
built-in modes matches the runner's execution semantics: `docker` if the
command runs in an environment where the working directory is mounted at
`/work`, `host` if it runs in place.

## Providing a toolchain from another module

A Vivado toolchain does not have to come from your root module: any Bazel
module that depends on `rules_vivado` can define `vivado_toolchain`
instances and register them in its own `MODULE.bazel` with
`register_toolchains()`. This lets e.g. an infrastructure module ship a
ready-made Vivado setup that all of its dependents pick up automatically.

Bazel selects among registered toolchains in this order: toolchains passed
via `--extra_toolchains` first, then the root module's registrations, then
each dependency module's registrations (in module graph order, which for
direct dependencies follows their `bazel_dep` declaration order). The
built-in `rules_vivado` toolchains participate in the same ordering.

To make the selection independent of that ordering, the
`--@rules_vivado//:vivado_mode` flag accepts a third value, `custom`, which
no built-in toolchain matches. A providing module gates its toolchain on
that mode:

```python
# In the providing module's BUILD.bazel:
toolchain(
    name = "provider_vivado_toolchain",
    target_settings = ["@rules_vivado//:vivado_mode_custom"],
    toolchain = ":provider_vivado",
    toolchain_type = "@rules_vivado//toolchains:toolchain_type",
)
```

```python
# In the providing module's MODULE.bazel:
register_toolchains("//:all")
```

and consumers activate it in their `.bazelrc`:

```
build --@rules_vivado//:vivado_mode=custom
```

Under `custom` mode the provided toolchain is guaranteed to be selected (or,
if none is registered, toolchain resolution fails with a clear error rather
than silently falling back to Docker). A working example lives in
[`integration/toolchain_provider`](../integration/toolchain_provider/).

## Notes on host mode

*   The host installation must contain `bin/setEnvAndRunCmd.sh` (present in
    stock Vivado installations), since all commands are launched through it.
*   Vivado requires a writable `HOME` (for `~/.Xilinx` and similar); in host
    mode `HOME` is redirected to the action's working directory, keeping build
    actions self-contained.
*   Host mode trades hermeticity for convenience: the build now depends on
    the machine's Vivado installation, so remote caching across machines with
    different installations should be used with care.

