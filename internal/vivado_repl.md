<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado REPL rule.

<a id="vivado_repl"></a>

## vivado_repl

<pre>
load("@rules_vivado//internal:vivado_repl.bzl", "vivado_repl")

vivado_repl(<a href="#vivado_repl-name">name</a>, <a href="#vivado_repl-env">env</a>, <a href="#vivado_repl-mount">mount</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_repl-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_repl-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_repl-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |


