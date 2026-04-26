# bazel_rules_vivado: Xilinx Vivado Rules for Bazel

[![Test](https://github.com/filmil/bazel_rules_vivado/actions/workflows/test.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/test.yml)
[![Publish to my Bazel registry](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish.yml)
[![Publish on Bazel Central Registry](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish-bcr.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish-bcr.yml)
[![Tag and Release](https://github.com/filmil/bazel_rules_vivado/actions/workflows/tag-and-release.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/tag-and-release.yml)

## Overview

`bazel_rules_vivado` provides Bazel rules for building Xilinx Vivado projects. This allows for a portable and ephemeral Vivado installation to be used within your Bazel builds.

This project relies on an approach that executes Vivado tools within a Docker container. This container is built from a Vivado installation archive you provide, as detailed in the prerequisites. The core mechanism is inspired by `bazel-rules-bid` (https://github.com/filmil/bazel-rules-bid), which enables running binaries within a Docker container as a Bazel build action.

It's important to note that distributing the Docker container itself is generally not feasible due to licensing and size, so you will need to build it locally. The setup of the required Vivado Docker image is handled by the `rules_vivado` project (https://github.com/agoessling/rules_vivado), which these rules depend upon. Please refer to their documentation for details on creating and installing the Vivado container.



## Documentation

| File | Documentation | Description |
| :--- | :--- | :--- |
| `doc.bzl` | [doc.md](doc.md) | Documentation helper functions |
| `build/vivado/rules.bzl` | [build/vivado/rules.md](build/vivado/rules.md) | Main Vivado rules exported by the project |
| `internal/defines.bzl` | [internal/defines.md](internal/defines.md) | Internal defines and common functions |
| `internal/providers.bzl` | [internal/providers.md](internal/providers.md) | Internal providers used by Vivado rules |
| `internal/vivado_generics.bzl` | [internal/vivado_generics.md](internal/vivado_generics.md) | Macro for generating generics TCL scripts |
| `internal/vivado_library.bzl` | [internal/vivado_library.md](internal/vivado_library.md) | Rule for defining a Vivado library |
| `internal/vivado_place_and_route.bzl` | [internal/vivado_place_and_route.md](internal/vivado_place_and_route.md) | Rule for Vivado place and route |
| `internal/vivado_place_and_route2.bzl` | [internal/vivado_place_and_route2.md](internal/vivado_place_and_route2.md) | Alternate rule for Vivado place and route |
| `internal/vivado_program_device.bzl` | [internal/vivado_program_device.md](internal/vivado_program_device.md) | Rule for programming a device |
| `internal/vivado_project.bzl` | [internal/vivado_project.md](internal/vivado_project.md) | Rule for defining a Vivado project |
| `internal/vivado_repl.bzl` | [internal/vivado_repl.md](internal/vivado_repl.md) | Rule for running Vivado REPL |
| `internal/vivado_gui.bzl` | [internal/vivado_gui.md](internal/vivado_gui.md) | Rule for running Vivado GUI |
| `internal/vivado_simulation.bzl` | [internal/vivado_simulation.md](internal/vivado_simulation.md) | Rule for running Vivado simulation |
| `internal/vivado_synthesis.bzl` | [internal/vivado_synthesis.md](internal/vivado_synthesis.md) | Rule for Vivado synthesis |
| `internal/vivado_synthesis2.bzl` | [internal/vivado_synthesis2.md](internal/vivado_synthesis2.md) | Alternate rule for Vivado synthesis |
| `internal/vivado_unisims_library.bzl` | [internal/vivado_unisims_library.md](internal/vivado_unisims_library.md) | Rule for Vivado UNISIMs library |

## Usage

### Running Vivado REPL

You can start a Vivado TCL REPL session using Bazel:

```bash
bazel run //build/vivado:repl
```

This will start Vivado in TCL mode within the container, mounting your current workspace.

### Running Vivado GUI

You can start the Vivado GUI using Bazel:

```bash
bazel run //build/vivado:gui
```

This requires an X11 server running on your host and will forward the X11 socket to the container.

## Prior Art

*   [agoessling/rules_vivado](https://github.com/agoessling/rules_vivado): This repository predates `bazel_rules_vivado`. It adopts a different approach, requiring a pre-installed Vivado instance rather than using a containerized version.

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
