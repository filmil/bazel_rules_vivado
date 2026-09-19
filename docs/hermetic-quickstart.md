# A hermetic Vivado, from scratch

This page is for someone who has been handed a repository that builds
FPGA things with Bazel and wants Vivado to work on their machine,
without having read anything else here first. It goes one step at a
time and says what each step is for. The reference for everything it
glosses over is [vivado-toolchain.md](vivado-toolchain.md).

## What "hermetic" means here

Normally you install Vivado yourself, it lands in `/opt/Xilinx` or
wherever you chose, and every build depends on what you happened to
install. Hermetic mode turns that around: you hand Bazel the installer
archive, and Bazel installs Vivado itself, in a place it manages, with
exactly the device families the project asked for. Nothing has to be on
your `PATH`, and two people on two machines get the same Vivado from
the same lines of configuration.

There is a price, and it is disk rather than difficulty: the first
build needs a few hundred gigabytes free and a couple of hours. After
that it costs nothing, because the installation is kept outside the
workspace and reused.

## Before you start

Three things:

*   **Bazel 9.2.0 or later**, through `bazelisk` if you have it. Earlier
    versions crash on a `file://` URL, which is how the archive is
    usually served, and the archive here is large enough to always hit
    the crash.
*   **The AMD installer archive.** It is a single `.tar`, named
    something like
    `FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar`, and AMD
    makes you log in to download it. Bazel will not fetch it for you
    from AMD; download it once, put it somewhere readable, and give
    Bazel the path.
*   **Room.** About 300 GB free while the install runs, of which around
    51 GB stays behind for a single device family. The section on cost
    below says where the rest goes.

## Step 1: the part everybody shares, in `MODULE.bazel`

Which archive to install, and which device families to install from it,
belong to the project rather than to you, so they live in the committed
`MODULE.bazel`. Only the root module may set them, which means the
repository you are building, not a dependency.

```python
bazel_dep(name = "rules_vivado", version = "3.10.2")

vivado = use_extension("@rules_vivado//:extensions.bzl", "vivado")
vivado.install(
    urls = ["file:///data/tools/archives/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_1.tar"],
    modules = ["Artix-7"],
)
```

If the project you are building already has those lines, you have
nothing to do in this step, except to make sure the file the `urls`
line names actually exists on your machine at that path.

`modules` is what keeps the installation from being enormous: it lists
the device families to install and leaves out everything else.
`Artix-7` covers a part like `xc7a200tfbg484-2`. If you name something
the installer does not have, the build fails and prints the whole menu,
so `modules = ["?"]` is a quick way to see the choices for your
archive.

## Step 2: the part that is yours, in `user.bazelrc`

`user.bazelrc` sits next to `.bazelrc` in the workspace, and the
project's `.bazelrc` pulls it in with

```
try-import %workspace%/user.bazelrc
```

`try-import` means Bazel reads the file if it is there and says nothing
if it is not. The file is in `.gitignore`, so it is yours: it never
reaches a commit, and it is the right home for anything that is true of
your machine rather than of the project.

Create it if it is not there, and put this in it:

```
# Let Bazel install and run Vivado itself.
common --@rules_vivado//:vivado_mode=hermetic

# Where that installation lives. Any path you can write to.
common --repo_env=RULES_VIVADO_CACHE=/data/cache/vivado-install
```

That is the whole of it. What each line does:

*   **The mode.** `vivado_mode` chooses where Vivado comes from:
    `hermetic` is the one described here, `host` uses an installation
    you made yourself, `docker` runs it in a container. A project that
    expects hermetic mode may already select it in the committed
    `.bazelrc`, in which case you can leave this line out; setting it
    again in `user.bazelrc` does no harm, and it is how you switch your
    own checkout without editing a shared file.
*   **The cache.** `RULES_VIVADO_CACHE` is the directory the
    installation is kept in. Leave the line out and it goes under
    Bazel's own per-user cache, roughly
    `~/.cache/bazel/_bazel_$USER/rules_vivado`. Set it when you want the
    50 GB somewhere else, most often a bigger disk, or a shared path so
    that several people or several checkouts use one installation.
    `--repo_env` is how a bazelrc sets a variable that a repository rule
    reads; exporting `RULES_VIVADO_CACHE` in your shell does the same
    thing.

If the project sets `install_cache` in its `vivado.install` block, that
wins over your variable. That is deliberate: a project that pins a
shared path is saying every checkout should use it.

### What does not belong here

There are flags named `vivado_path` and `vivado_version`, and they look
like what you want. They are not. They belong to `host` mode, where
they say where your own installation is. In hermetic mode Bazel knows
where it put Vivado, and the version comes from the archive. Setting
them will not point hermetic mode anywhere.

## Step 3: run something

Any target that uses Vivado will do. The ruleset ships a small one:

```sh
bazel test //build/tests/vivado:blinky_synth_hermetic_test
```

It is tagged `manual`, so it stays out of `bazel test //...` and you run
it by name. The first run installs Vivado and then synthesizes a
blinky; later runs skip straight to the synthesis.

You can tell the installation worked without reading the log. The
directory you named in `RULES_VIVADO_CACHE` holds one subdirectory per
installation, named for the version and the selection:

```
/data/cache/vivado-install/
└── 2025.2-18cd19a4392e25e8/
    ├── COMPLETE
    └── install/
```

The `COMPLETE` file is written last, so a directory that has it holds a
finished installation. If you would rather ask Bazel,
`bazel fetch --repo=@vivado_hermetic` finishes in seconds once the
installation is there, and takes two hours if it is not.

## What the first build costs

Measured once, end to end, on an eight core x86-64 machine with the
archive and the Bazel output base on the same pair of spinning disks,
`modules = ["Artix-7"]`, Vivado 2025.2:

| Phase | Duration |
| :--- | ---: |
| Copy the archive, write it to the repository cache, unpack it | 1h 52m |
| Batch install | 13m |
| First simulation output after that | 2m |

| Thing | Size |
| :--- | ---: |
| Installer archive | 95.7 GiB |
| Peak free space consumed | about 291 GB |
| Installed Vivado, `Artix-7` only | 51.2 GiB |

The surprise in that table is that installing is the cheap part. The
two hours are three sequential passes over a 100 GB file: copying it
into the output base, writing a second copy into Bazel's repository
cache, and unpacking it. On flash rather than spinning disks, expect
markedly less.

It happens once. The installation survives `bazel clean --expunge`,
because it lives in the cache rather than in the workspace's output
base, and a refetch that finds the `COMPLETE` marker takes seconds.
A reinstall happens only when the selection changes: a different
archive, different modules, a different edition.

## Sharing one installation

Two workspaces share an installation when three things agree: the
cache directory, the archive URL, and the selection (`modules`,
`edition`, `sha256` if it is set). Those make up the name of the
directory inside the cache, so state them identically and the second
workspace finds the first one's installation and installs nothing.
Say them differently, even in a way that would install the same bytes,
and you get a second copy.

## When it goes wrong

*   **`No space left on device`, partway in.** The peak is around
    300 GB, not the 51 GB that remains. Free space or point
    `RULES_VIVADO_CACHE` and Bazel's output base at a larger disk.
*   **A `NullPointerException` mentioning `URI.getHost()`.** Bazel
    9.1.0 with a `file://` URL. Upgrade to 9.2.0.
*   **The build fails with a menu of module names.** The `modules` list
    named something the installer does not have, or named it
    ambiguously. The message prints the whole menu; pick from it.
*   **It starts installing again when you expected a cache hit.** The
    selection changed. Compare the `vivado.install` block and the cache
    directory with the workspace that already has the installation.
*   **A toolchain error, or Vivado plainly not being used.** Check that
    the mode reached Bazel by passing it on the command line instead:
    `bazel test --@rules_vivado//:vivado_mode=hermetic <target>`. If
    that works and `user.bazelrc` does not, the file is in the wrong
    place. It goes beside `.bazelrc` at the workspace root, and the
    project's `.bazelrc` has to `try-import` it; a misspelled flag is
    reported, but a file Bazel never reads is silent.

## Where to go next

[vivado-toolchain.md](vivado-toolchain.md) is the reference: every
attribute of `vivado.install`, the full module menu for the 2025.2
installer, the other modes, the licensing note, and the details of the
install cache. [usage.md](usage.md) covers what to do with the
toolchain once it works.
