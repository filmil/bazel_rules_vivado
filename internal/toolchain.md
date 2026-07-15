<!-- Generated with Stardoc: http://skydoc.bazel.build -->

The Vivado execution toolchain.

The toolchain decides *how* Vivado tools are invoked: either inside the local
`xilinx-vivado:<version>` Docker container (the default), or directly on the
host, using a preexisting Vivado installation.

Selection happens through the `//:vivado_mode` build setting flag. Users pick
the host mode by adding this to their `.bazelrc`:

```
build --@rules_vivado//:vivado_mode=host
```

Both modes share a single command line format: rules generate a command that
starts with a "runner" executable. In docker mode the runner is
`@rules_bid//build:docker_run`, which wraps the command in `docker run`; in
host mode it is `//internal:host_run`, which accepts the same flags (ignoring
the docker-specific ones) and executes the command directly on the host.

Users with custom setups can define and register their own `vivado_toolchain`
instance instead of using the built-in ones in `//toolchains`.

<a id="vivado_toolchain"></a>

## vivado_toolchain

<pre>
load("@rules_vivado//internal:toolchain.bzl", "vivado_toolchain")

vivado_toolchain(<a href="#vivado_toolchain-name">name</a>, <a href="#vivado_toolchain-container">container</a>, <a href="#vivado_toolchain-mode">mode</a>, <a href="#vivado_toolchain-runner">runner</a>, <a href="#vivado_toolchain-vivado_path">vivado_path</a>, <a href="#vivado_toolchain-vivado_version">vivado_version</a>)
</pre>

Declares a Vivado execution toolchain.

The built-in instances live in `//toolchains`. Declare your own instance (and
register it with a `toolchain()` wrapper) to customize how Vivado is invoked,
e.g. to point at a nonstandard host installation:

```python
vivado_toolchain(
    name = "my_host_vivado",
    mode = "host",
    vivado_path = "/tools/Xilinx/Vivado/2024.2",
    vivado_version = "2024.2",
    runner = "@rules_vivado//internal:host_run",
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_toolchain-container"></a>container |  The Vivado Docker image (docker mode only). Empty means derived from the version as `xilinx-vivado:<version>`, unless overridden by the --//internal:vivado_container flag.   | String | optional |  `""`  |
| <a id="vivado_toolchain-mode"></a>mode |  How Vivado is executed: in the Docker container, or directly on the host.   | String | required |  |
| <a id="vivado_toolchain-runner"></a>runner |  The runner executable that command lines are prefixed with: `@rules_bid//build:docker_run` for docker mode, `//internal:host_run` for host mode. Both accept the same command line flags.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="vivado_toolchain-vivado_path"></a>vivado_path |  The Vivado install path (inside the container in docker mode; on the host filesystem in host mode). Empty means derived from the version as `/opt/Xilinx/<version>/Vivado`, unless overridden by the --//internal:vivado_path flag.   | String | optional |  `""`  |
| <a id="vivado_toolchain-vivado_version"></a>vivado_version |  The Vivado version. Empty means the built-in default, unless overridden by the --//internal:vivado_version flag.   | String | optional |  `""`  |


<a id="rlocation_path"></a>

## rlocation_path

<pre>
load("@rules_vivado//internal:toolchain.bzl", "rlocation_path")

rlocation_path(<a href="#rlocation_path-ctx">ctx</a>, <a href="#rlocation_path-file">file</a>)
</pre>

Computes the runfiles (rlocation) path of a file.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rlocation_path-ctx"></a>ctx |  The rule context.   |  none |
| <a id="rlocation_path-file"></a>file |  The file to compute the rlocation path for.   |  none |

**RETURNS**

The path suitable for lookup with `rlocation` in bash scripts.


<a id="vivado_config"></a>

## vivado_config

<pre>
load("@rules_vivado//internal:toolchain.bzl", "vivado_config")

vivado_config(<a href="#vivado_config-ctx">ctx</a>)
</pre>

Resolves the Vivado configuration from the Vivado toolchain.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="vivado_config-ctx"></a>ctx |  The rule context. The rule must declare `toolchains = [VIVADO_TOOLCHAIN_TYPE]`.   |  none |

**RETURNS**

A struct with fields:
  mode: "docker" or "host".
  is_host: convenience bool, True in host mode.
  vivado_version: the Vivado version string.
  container: the Docker image (meaningful in docker mode only).
  vivado_path: the Vivado install path.
  runner: the runner executable, as a FilesToRunProvider. Pass it in
    `tools = [...]` of actions that run Vivado, and use
    `runner.executable.path` as the script path for `script_cmd`.
  runner_default_runfiles: the runner's default runfiles, for rules
    that place the runner into runfiles of generated scripts.


