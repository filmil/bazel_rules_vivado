# bazel_rules_vivado: Xilinx Vivado Rules for Bazel

[![Test](https://github.com/filmil/bazel_rules_vivado/actions/workflows/test.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/test.yml)
[![Publish to my Bazel registry](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish.yml)
[![Publish on Bazel Central Registry](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish-bcr.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/publish-bcr.yml)
[![Tag and Release](https://github.com/filmil/bazel_rules_vivado/actions/workflows/tag-and-release.yml/badge.svg)](https://github.com/filmil/bazel_rules_vivado/actions/workflows/tag-and-release.yml)

## Overview

`bazel_rules_vivado` provides Bazel rules for building Xilinx Vivado projects. This allows for a portable and ephemeral Vivado installation to be used within your Bazel builds.

By default, this project executes Vivado tools within a Docker container. This container is built from a Vivado installation archive you provide, as detailed in the prerequisites. The core mechanism is inspired by `bazel-rules-bid` (https://github.com/filmil/bazel-rules-bid), which enables running binaries within a Docker container as a Bazel build action.

It's important to note that distributing the Docker container itself is generally not feasible due to licensing and size, so you will need to build it locally. The setup of the required Vivado Docker image is handled by the `rules_vivado` project (https://github.com/agoessling/rules_vivado), which these rules depend upon. Please refer to their documentation for details on creating and installing the Vivado container.

Docker is only the default, not a requirement: the rules can also run a Vivado installed on your machine, or download and install Vivado themselves. See the next section.

## Choosing how Vivado is executed

All rules in this repository invoke Vivado through a Bazel toolchain. The toolchain decides *how* Vivado runs; the rules themselves are agnostic to it. Four modes are available:

| Mode | What it gives you | What it needs |
| :--- | :--- | :--- |
| `docker` (default) | Repeatable builds in a container; the host machine needs no Vivado of its own. | Docker, plus the locally built `xilinx-vivado:<version>` image (see prerequisites). |
| `host` | Uses the Vivado already installed on the machine; the quickest way to get started if you have one. | A local Vivado installation. |
| `hermetic` | Bazel downloads the AMD installer and installs Vivado itself: every machine building the workspace gets the identical toolchain, with no Docker and no manual install. | The installer archive URL; about 300 GB of transient disk space; Bazel 9.2.0+ for `file://` URLs. |
| `custom` | Full control: bring your own toolchain — a podman wrapper, a remote build machine, per-platform selection, or one shipped by a dependency module. | A registered `vivado_toolchain`. |

The mode is selected with a build setting flag in your `.bazelrc`, for example:

```
build --@rules_vivado//:vivado_mode=host
```

Everything beyond that one flag — configuring versions and paths, setting up a
hermetic installation and what it costs, defining custom toolchains, host mode
caveats — is covered in [docs/vivado-toolchain.md](docs/vivado-toolchain.md).

## Documentation

| Document | Contents |
| :--- | :--- |
| [docs/vivado-toolchain.md](docs/vivado-toolchain.md) | The Vivado toolchain in detail: mode selection, version and path flags, hermetic installation (configuration, component selection, measured costs, the install cache), custom and third-party toolchains, host mode notes. |
| [docs/usage.md](docs/usage.md) | Using the rules: REPL, GUI, generating custom AMD IP. |
| [docs/reference.md](docs/reference.md) | Per-file rule and API reference, generated from the `.bzl` sources. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to report bugs, suggest enhancements, and submit pull requests. |

## Prior Art

*   [agoessling/rules_vivado](https://github.com/agoessling/rules_vivado): This repository predates `bazel_rules_vivado`. It adopts a different approach, requiring a pre-installed Vivado instance rather than using a containerized version.
*   [hw-bzl/rules_vivado](https://github.com/hw-bzl/rules_vivado): Another set of Bazel rules for the Vivado FPGA toolchain.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to
report bugs, suggest enhancements, and submit pull requests.

## License

This project is licensed under the Apache License 2.0; see [LICENSE](LICENSE).
