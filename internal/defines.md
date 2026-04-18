<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Defines variables and functions used in Vivado rules.

<a id="script_cmd"></a>

## script_cmd

<pre>
load("@rules_vivado//internal:defines.bzl", "script_cmd")

script_cmd(<a href="#script_cmd-script_path">script_path</a>, <a href="#script_cmd-dir_reference">dir_reference</a>, <a href="#script_cmd-cache_dir">cache_dir</a>, <a href="#script_cmd-source_dir">source_dir</a>, <a href="#script_cmd-mounts">mounts</a>, <a href="#script_cmd-envs">envs</a>, <a href="#script_cmd-tools">tools</a>, <a href="#script_cmd-freeargs">freeargs</a>,
           <a href="#script_cmd-workdir_name">workdir_name</a>)
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

**RETURNS**

The generated command line as a string.


