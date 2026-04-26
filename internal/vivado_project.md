<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado project rule.

<a id="vivado_project"></a>

## vivado_project

<pre>
load("@rules_vivado//internal:vivado_project.bzl", "vivado_project")

vivado_project(<a href="#vivado_project-name">name</a>, <a href="#vivado_project-deps">deps</a>, <a href="#vivado_project-srcs">srcs</a>, <a href="#vivado_project-hdrs">hdrs</a>, <a href="#vivado_project-defines">defines</a>, <a href="#vivado_project-env">env</a>, <a href="#vivado_project-include_dirs">include_dirs</a>, <a href="#vivado_project-mount">mount</a>, <a href="#vivado_project-part">part</a>, <a href="#vivado_project-top_level">top_level</a>, <a href="#vivado_project-xdcs">xdcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_project-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_project-deps"></a>deps |  The list of library dependencies   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_project-srcs"></a>srcs |  A list of source files.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_project-hdrs"></a>hdrs |  A list of header files.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_project-defines"></a>defines |  A list of defines.   | List of strings | optional |  `[]`  |
| <a id="vivado_project-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_project-include_dirs"></a>include_dirs |  A list of include directories.   | List of strings | optional |  `[]`  |
| <a id="vivado_project-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_project-part"></a>part |  The part that is targeted by this project   | String | required |  |
| <a id="vivado_project-top_level"></a>top_level |  Top level entity name   | String | required |  |
| <a id="vivado_project-xdcs"></a>xdcs |  A list of constraints files to use.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


