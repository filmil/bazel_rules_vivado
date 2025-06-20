# bazel_rules_vivado: Xilinx Vivado Rules for Bazel

## Overview

`bazel_rules_vivado` provides Bazel rules for building Xilinx Vivado projects. This allows for a portable and ephemeral Vivado installation to be used within your Bazel builds.

This project relies on an approach that executes Vivado tools within a Docker container. This container is built from a Vivado installation archive you provide, as detailed in the prerequisites. The core mechanism is inspired by `bazel-rules-bid` (https://github.com/filmil/bazel-rules-bid), which enables running binaries within a Docker container as a Bazel build action.

It's important to note that distributing the Docker container itself is generally not feasible due to licensing and size, so you will need to build it locally.

## Prerequisites

The primary prerequisite is a Docker container image of the Xilinx Vivado suite. This image is built by `rules_vivado` (https://github.com/agoessling/rules_vivado) using a Vivado installation archive that you must create.

### Creating the Vivado Installation Archive (`path_to_the_image.tgz`)

The `path_to_the_image.tgz` mentioned in the setup command is a gzipped tarball (`.tgz`) containing the Xilinx Vivado installation files. Follow these steps to create it:

1.  **Download Vivado Installer**:
    *   Visit the [Xilinx Downloads page](https://www.xilinx.com/support/download.html).
    *   Select your desired Vivado version (e.g., 2022.2).
    *   Download the "Vivado HLx All OS installer with Full Product Installation" (a large file, typically 70-90GB). A Xilinx account is required.

2.  **Extract Installation Files**:
    *   Make the downloaded installer executable:
        ```bash
        chmod +x Xilinx_Unified_*.bin
        ```
    *   Run the installer with flags to download only, not install. Specify a download directory:
        ```bash
        ./Xilinx_Unified_YYYY.V_MMDD_BBBB_OS.bin --noexec --nodeps --keep --dir /path/to/your/vivado_download_directory
        ```
        *(Replace `Xilinx_Unified_YYYY.V_MMDD_BBBB_OS.bin` with your installer's filename and `/path/to/your/vivado_download_directory` with your chosen path).*
    *   This downloads the complete Vivado installation (potentially >200GB).

3.  **Create the Archive**:
    *   Navigate into the download directory. You should find a subdirectory like `Xilinx_Vivado_Vitis_Update_YYYY.V_MMDD_BBBB/`.
    *   Create a gzipped tarball of this subdirectory:
        ```bash
        tar -czvf vivado_installation_archive.tgz Xilinx_Vivado_Vitis_Update_YYYY.V_MMDD_BBBB
        ```
        *(Ensure the directory name matches the one created by the installer).*
    *   This `vivado_installation_archive.tgz` is the file you'll use.

### Installing the Docker Image Prerequisite

Once `path_to_the_image.tgz` is ready, you can build and install the Vivado Docker image using:

```bash
bazel run //prerequisites:vivado -- path_to_the_image.tgz
```

This process can take several hours and requires significant disk space (the Vivado container can exceed 250GiB). Fortunately, it's a one-time setup.

## Installation and Setup

To use `bazel_rules_vivado` in your Bazel project, modify your `WORKSPACE` file:

```bazel
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_rules_vivado",
    sha256 = "<sha256_checksum>",  # TODO: Replace with the actual checksum of the release
    strip_prefix = "bazel_rules_vivado-<commit_sha>",  # TODO: Replace with the release tag/commit
    urls = ["https://github.com/filmil/bazel_rules_vivado/archive/<commit_sha>.zip"], # TODO: Update URL
)

load("@bazel_rules_vivado//:repositories.bzl", "bazel_rules_vivado_dependencies")

bazel_rules_vivado_dependencies()
```

**Note**: Replace `<sha256_checksum>` and `<commit_sha>` with the correct values from the specific release of `bazel_rules_vivado` you intend to use.

## Usage

After setting up the WORKSPACE, you can use the provided rules in your `BUILD` files.

### `vivado_project` Rule

The `vivado_project` rule is used to define and build a Vivado project.

**Attributes**:

*   `name`: (String, mandatory) The name of the target.
*   `srcs`: (List of labels, mandatory) Source files for the project (e.g., VHDL, Verilog, XDC).
*   `part`: (String, mandatory) The Xilinx part number for the target device (e.g., `xc7a35tcpg236-1`).
*   `top`: (String, mandatory) The name of the top-level module in your design.

**Example**:

```bazel
load("@bazel_rules_vivado//:vivado.bzl", "vivado_project")

vivado_project(
    name = "my_fpga_project",
    srcs = [
        "//path/to/hdl:my_project_top.vhd",
        "//path/to/hdl:another_module.vhd",
        "//path/to/constraints:constraints.xdc",
    ],
    part = "xc7a35tcpg236-1",
    top = "my_project_top",
)
```

To build this project, run:

```bash
bazel build //your/package:my_fpga_project
```

This command will generate the bitstream file for your project, typically located in the `bazel-bin/...` directory.

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
