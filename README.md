# bazel_rules_vivado: Xilinx Vivado Rules for Bazel

[![Test](https://github.com/filmil/bazel_rules_vivado/actions/workflows/test.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/test.yml)
[![Publish to my Bazel registry](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish.yml)
[![Publish on Bazel Central Registry](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish-bcr.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish-bcr.yml)
[![Tag and Release](https://github.com/filmil/bazel_rules_vivado/actions/workflows/tag-and-release.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/tag-and-release.yml)

## Overview

`bazel_rules_vivado` provides Bazel rules for building Xilinx Vivado projects. This allows for a portable and ephemeral Vivado installation to be used within your Bazel builds.

By default, this project executes Vivado tools within a Docker container. This container is built from a Vivado installation archive you provide, as detailed in the prerequisites. The core mechanism is inspired by `bazel-rules-bid` (https://github.com/filmil/bazel-rules-bid), which enables running binaries within a Docker container as a Bazel build action.

It's important to note that distributing the Docker container itself is generally not feasible due to licensing and size, so you will need to build it locally. The setup of the required Vivado Docker image is handled by the `rules_vivado` project (https://github.com/agoessling/rules_vivado), which these rules depend upon. Please refer to their documentation for details on creating and installing the Vivado container.

Alternatively, if you already have Vivado installed on your machine, you can configure the rules to use that installation directly, without Docker. See [Choosing how Vivado is executed](#choosing-how-vivado-is-executed-the-vivado-toolchain) below.



## Documentation

| File | Documentation | Description |
| :--- | :--- | :--- |
| `doc.bzl` | [doc.md](doc.md) | Documentation helper functions |
| `build/vivado/rules.bzl` | [build/vivado/rules.md](build/vivado/rules.md) | Main Vivado rules exported by the project |
| `internal/defines.bzl` | [internal/defines.md](internal/defines.md) | Internal defines and common functions |
| `internal/providers.bzl` | [internal/providers.md](internal/providers.md) | Internal providers used by Vivado rules |
| `internal/toolchain.bzl` | [internal/toolchain.md](internal/toolchain.md) | The Vivado execution toolchain (docker or host mode) |
| `internal/vivado_generics.bzl` | [internal/vivado_generics.md](internal/vivado_generics.md) | Macro for generating generics TCL scripts |
| `internal/vivado_library.bzl` | [internal/vivado_library.md](internal/vivado_library.md) | Rule for defining a Vivado library |
| `internal/vivado_place_and_route.bzl` | [internal/vivado_place_and_route.md](internal/vivado_place_and_route.md) | Rule for Vivado place and route |
| `internal/vivado_place_and_route2.bzl` | [internal/vivado_place_and_route2.md](internal/vivado_place_and_route2.md) | Alternate rule for Vivado place and route |
| `internal/vivado_program_device.bzl` | [internal/vivado_program_device.md](internal/vivado_program_device.md) | Rule for programming a device |
| `internal/vivado_project.bzl` | [internal/vivado_project.md](internal/vivado_project.md) | Rule for defining a Vivado project |
| `internal/vivado_repl.bzl` | [internal/vivado_repl.md](internal/vivado_repl.md) | Rule for running Vivado REPL |
| `internal/vivado_gui.bzl` | [internal/vivado_gui.md](internal/vivado_gui.md) | Rule for running Vivado GUI |
| `internal/vivado_ip.bzl` | [internal/vivado_ip.md](internal/vivado_ip.md) | Rule for generating custom AMD IP |
| `internal/vivado_simulation.bzl` | [internal/vivado_simulation.md](internal/vivado_simulation.md) | Rule for running Vivado simulation |
| `internal/vivado_synthesis.bzl` | [internal/vivado_synthesis.md](internal/vivado_synthesis.md) | Rule for Vivado synthesis |
| `internal/vivado_synthesis2.bzl` | [internal/vivado_synthesis2.md](internal/vivado_synthesis2.md) | Alternate rule for Vivado synthesis |
| `internal/vivado_unisims_library.bzl` | [internal/vivado_unisims_library.md](internal/vivado_unisims_library.md) | Rule for Vivado UNISIMs library |

## Choosing how Vivado is executed (the Vivado toolchain)

All rules in this repository invoke Vivado through a Bazel toolchain. The
toolchain decides *how* Vivado runs; the rules themselves are agnostic to it.
Two modes are built in:

| Mode | What it does | Requirements |
| :--- | :--- | :--- |
| `docker` (default) | Runs Vivado inside the local `xilinx-vivado:<version>` Docker image. | Docker, plus the locally built Vivado image (see prerequisites). |
| `host` | Runs a Vivado installed on the host machine directly. | A local Vivado installation. |

### Selecting the mode

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

### Configuring versions and paths

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

### Defining a custom toolchain

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

### Notes on host mode

*   The host installation must contain `bin/setEnvAndRunCmd.sh` (present in
    stock Vivado installations), since all commands are launched through it.
*   Vivado requires a writable `HOME` (for `~/.Xilinx` and similar); in host
    mode `HOME` is redirected to the action's working directory, keeping build
    actions self-contained.
*   Host mode trades hermeticity for convenience: the build now depends on
    the machine's Vivado installation, so remote caching across machines with
    different installations should be used with care.

## Usage

### Running Vivado REPL

You can start a Vivado TCL REPL session using Bazel:

```bash
bazel run //build/vivado:repl
```

This will start Vivado in TCL mode within the container, mounting your current workspace.

You can also pass a custom TCL script to be executed upon startup using the `script` attribute:

```python
vivado_repl(
    name = "repl_with_script",
    script = "my_script.tcl",
)
```

### Running Vivado GUI

You can start the Vivado GUI using Bazel:

```bash
bazel run //build/vivado:gui
```

This requires an X11 server running on your host and will forward the X11 socket to the container.

Similarly to the REPL, you can pass a custom TCL script to be executed upon startup:

```python
vivado_gui(
    name = "gui_with_script",
    script = "my_script.tcl",
)
```

### Generating Custom AMD IP

You can generate and configure custom AMD IP blocks and use them as libraries:

```python
vivado_ip(
    name = "clk_wiz_0",
    vlnv = "xilinx.com:ip:clk_wiz:6.0",
    part = "xc7a200tfbg484-2",
    config = {
        "PRIM_SOURCE": "Single_ended_clock_capable_pin",
        "CLKOUT1_REQUESTED_OUT_FREQ": "100.000",
    },
)

# Then use clk_wiz_0 as a dependency in other rules
vivado_simulation(
    name = "sim",
    library = ":my_lib",
    deps = [":clk_wiz_0"],
    top = "tb",
)
```

## Prior Art

*   [agoessling/rules_vivado](https://github.com/agoessling/rules_vivado): This repository predates `bazel_rules_vivado`. It adopts a different approach, requiring a pre-installed Vivado instance rather than using a containerized version.
*   [hw-bzl/rules_vivado](https://github.com/hw-bzl/rules_vivado): Another set of Bazel rules for the Vivado FPGA toolchain.

## Contributing

Contributions are welcome! If you find issues or have suggestions for improvements, please open an issue or submit a pull request on GitHub.

### Reporting Bugs

When reporting a bug, please include:

*   A clear description of the bug.
*   Steps to reproduce it.
*   `bazel_rules_vivado` version.
*   Your OS and Bazel version.
*   Relevant error messages or logs.

### Suggesting Enhancements

For new features or enhancements, please open a GitHub issue for discussion first. This helps align contributions with project goals.

### Pull Request Guidelines

1.  **Fork & Branch**: Fork the repository and create a new branch for your changes (e.g., `git checkout -b feature/my-new-feature master`).
2.  **Develop**: Implement your fix or feature.
3.  **Test**: Ensure your changes don't break existing functionality. Add tests for new features if applicable. (Testing infrastructure details are TBD).
4.  **Commit**: Use clear and descriptive commit messages (e.g., `Fix: Correct handling of XDC file parsing`).
5.  **Push**: Push your branch to your fork (`git push origin feature/my-new-feature`).
6.  **Submit PR**: Open a pull request against the main `bazel_rules_vivado` repository with a comprehensive description of your changes.

## License

This project is licensed under the Apache License 2.0. A copy of the license text can be found at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

It is recommended to include a `LICENSE` file in the root of this repository containing the full text of the Apache License 2.0.
