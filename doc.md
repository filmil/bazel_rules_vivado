<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Module providing documentation helper functions.

<a id="script_cmd"></a>

## script_cmd

<pre>
load("@rules_vivado//:doc.bzl", "script_cmd")

script_cmd(<a href="#script_cmd-script_path">script_path</a>, <a href="#script_cmd-dir_reference">dir_reference</a>, <a href="#script_cmd-cache_dir">cache_dir</a>, <a href="#script_cmd-source_dir">source_dir</a>, <a href="#script_cmd-mounts">mounts</a>, <a href="#script_cmd-envs">envs</a>, <a href="#script_cmd-tools">tools</a>, <a href="#script_cmd-freeargs">freeargs</a>,
           <a href="#script_cmd-workdir_name">workdir_name</a>, <a href="#script_cmd-container">container</a>)
</pre>

Generates the command line to run a Vivado command through a runner.

The generated command line starts with the runner script at `script_path`
and works with both runners the Vivado toolchain can supply: the docker
runner (`@rules_bid//build:docker_run`) consumes all flags and executes
the command inside the container, while the host runner
(`//internal:host_run`) ignores the docker-specific flags and executes
the command directly on the host. Pass
`vivado_config(ctx).runner.executable.path` as `script_path` to honor the
toolchain selection.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="script_cmd-script_path"></a>script_path |  Path to the runner script (docker_run or host_run).   |  none |
| <a id="script_cmd-dir_reference"></a>dir_reference |  Directory reference.   |  none |
| <a id="script_cmd-cache_dir"></a>cache_dir |  Cache directory.   |  none |
| <a id="script_cmd-source_dir"></a>source_dir |  Source directory.   |  `""` |
| <a id="script_cmd-mounts"></a>mounts |  Mounts to add.   |  `None` |
| <a id="script_cmd-envs"></a>envs |  Environment variables to add.   |  `None` |
| <a id="script_cmd-tools"></a>tools |  Tools to add.   |  `None` |
| <a id="script_cmd-freeargs"></a>freeargs |  Additional arguments to pass.   |  `[]` |
| <a id="script_cmd-workdir_name"></a>workdir_name |  The working directory name.   |  `"/work"` |
| <a id="script_cmd-container"></a>container |  Optional container image override. When None, the default CONTAINER is used. Pass `vivado_config(ctx).container` to honor user-supplied build setting flags.   |  `None` |

**RETURNS**

The generated command line as a string.


