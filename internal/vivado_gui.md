<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado GUI rule.

<a id="vivado_gui"></a>

## vivado_gui

<pre>
load("@rules_vivado//internal:vivado_gui.bzl", "vivado_gui")

vivado_gui(<a href="#vivado_gui-name">name</a>, <a href="#vivado_gui-env">env</a>, <a href="#vivado_gui-mount">mount</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_gui-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_gui-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_gui-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |


