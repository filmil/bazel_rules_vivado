<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado synthesis rule.

<a id="vivado_synthesis"></a>

## vivado_synthesis

<pre>
load("@rules_vivado//internal:vivado_synthesis.bzl", "vivado_synthesis")

vivado_synthesis(<a href="#vivado_synthesis-name">name</a>, <a href="#vivado_synthesis-env">env</a>, <a href="#vivado_synthesis-mount">mount</a>, <a href="#vivado_synthesis-project">project</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_synthesis-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_synthesis-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis-project"></a>project |  The Vivado project to work on   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


