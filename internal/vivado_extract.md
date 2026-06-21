<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rule to extract files out of the Vivado Docker image.

Some Vivado artifacts (for example the `hw_server` binary and the Digilent
cable-driver shared libraries) are needed at runtime but are not meant to be
checked into a repository. Because every `rules_vivado` action already runs
inside the locally provided `xilinx-vivado:<version>` Docker image, those files
are available on the image's filesystem and can be copied out as a normal Bazel
build action. `vivado_extract` does exactly that: it declares one output per
requested file and copies it from the container into the Bazel output tree.

<a id="vivado_extract"></a>

## vivado_extract

<pre>
load("@rules_vivado//internal:vivado_extract.bzl", "vivado_extract")

vivado_extract(<a href="#vivado_extract-name">name</a>, <a href="#vivado_extract-env">env</a>, <a href="#vivado_extract-files">files</a>, <a href="#vivado_extract-mount">mount</a>)
</pre>

Extracts files from the Vivado Docker image into Bazel outputs.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_extract-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_extract-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_extract-files"></a>files |  Map of output path (relative to this package) to a path inside the Vivado container. A container path starting with '/' is treated as absolute; otherwise it is resolved relative to the Vivado install path (e.g. /opt/Xilinx/<version>/Vivado).   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | required |  |
| <a id="vivado_extract-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |


