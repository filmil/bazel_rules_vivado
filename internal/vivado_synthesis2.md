<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado synthesis2 rule.

<a id="vivado_synthesis2"></a>

## vivado_synthesis2

<pre>
load("@rules_vivado//internal:vivado_synthesis2.bzl", "vivado_synthesis2")

vivado_synthesis2(<a href="#vivado_synthesis2-name">name</a>, <a href="#vivado_synthesis2-deps">deps</a>, <a href="#vivado_synthesis2-srcs">srcs</a>, <a href="#vivado_synthesis2-data">data</a>, <a href="#vivado_synthesis2-hdrs">hdrs</a>, <a href="#vivado_synthesis2-defines">defines</a>, <a href="#vivado_synthesis2-env">env</a>, <a href="#vivado_synthesis2-generics">generics</a>, <a href="#vivado_synthesis2-include_dirs">include_dirs</a>, <a href="#vivado_synthesis2-mount">mount</a>, <a href="#vivado_synthesis2-part">part</a>,
                  <a href="#vivado_synthesis2-top">top</a>, <a href="#vivado_synthesis2-xdcs">xdcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_synthesis2-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_synthesis2-deps"></a>deps |  The sources for the libraries   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_synthesis2-srcs"></a>srcs |  The sources for the `work` library   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_synthesis2-data"></a>data |  Other data   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_synthesis2-hdrs"></a>hdrs |  The headers for the `work` library if verilog   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_synthesis2-defines"></a>defines |  A dictionary of defines.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis2-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis2-generics"></a>generics |  A dictionary of generics.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis2-include_dirs"></a>include_dirs |  A list of include directories.   | List of strings | optional |  `[]`  |
| <a id="vivado_synthesis2-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis2-part"></a>part |  The part that is targeted by this project   | String | required |  |
| <a id="vivado_synthesis2-top"></a>top |  Mandatory name of the top level entity   | String | required |  |
| <a id="vivado_synthesis2-xdcs"></a>xdcs |  Constraint files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


