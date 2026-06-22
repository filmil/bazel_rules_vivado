<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado REPL rule.

<a id="vivado_repl"></a>

## vivado_repl

<pre>
load("@rules_vivado//internal:vivado_repl.bzl", "vivado_repl")

vivado_repl(<a href="#vivado_repl-name">name</a>, <a href="#vivado_repl-data">data</a>, <a href="#vivado_repl-env">env</a>, <a href="#vivado_repl-mount">mount</a>, <a href="#vivado_repl-script">script</a>, <a href="#vivado_repl-use_terminal">use_terminal</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_repl-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_repl-data"></a>data |  Files (or targets whose default outputs and runfiles) to make available in the REPL's working directory inside the container.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_repl-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_repl-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_repl-script"></a>script |  Optional TCL script to run on startup.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="vivado_repl-use_terminal"></a>use_terminal |  If true (default), run the container with `-it` so Vivado gets an interactive TTY. Set to false for non-interactive contexts (e.g. piped input or CI), where `-it` would fail with 'the input device is not a TTY'.   | Boolean | optional |  `True`  |


