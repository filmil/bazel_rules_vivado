<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Defines variables and functions used in Vivado rules.

<a id="script_cmd"></a>

## script_cmd

<pre>
load("@rules_vivado//internal:defines.bzl", "script_cmd")

script_cmd(<a href="#script_cmd-script_path">script_path</a>, <a href="#script_cmd-dir_reference">dir_reference</a>, <a href="#script_cmd-cache_dir">cache_dir</a>, <a href="#script_cmd-source_dir">source_dir</a>, <a href="#script_cmd-mounts">mounts</a>, <a href="#script_cmd-envs">envs</a>, <a href="#script_cmd-tools">tools</a>, <a href="#script_cmd-freeargs">freeargs</a>,
           <a href="#script_cmd-workdir_name">workdir_name</a>, <a href="#script_cmd-container">container</a>)
</pre>

Generates the command line to run a docker container.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="script_cmd-script_path"></a>script_path |  Path to the docker run script.   |  none |
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


<a id="vivado_config"></a>

## vivado_config

<pre>
load("@rules_vivado//internal:defines.bzl", "vivado_config")

vivado_config(<a href="#vivado_config-ctx">ctx</a>)
</pre>

Resolves the Vivado configuration from build setting flags.

Falls back to DEFAULT_VIVADO_VERSION / DEFAULT_CONTAINER / DEFAULT_VIVADO_PATH
when a flag is left at its empty default. When only `vivado_version` is set,
the container image and Vivado install path are derived from it.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="vivado_config-ctx"></a>ctx |  The rule context. The rule's `attrs` must include VIVADO_CONFIG_ATTRS.   |  none |

**RETURNS**

A struct with fields `vivado_version`, `container`, and `vivado_path`.


