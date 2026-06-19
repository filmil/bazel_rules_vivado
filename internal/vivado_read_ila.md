<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado read ILA rule.

<a id="vivado_read_ila"></a>

## vivado_read_ila

<pre>
load("@rules_vivado//internal:vivado_read_ila.bzl", "vivado_read_ila")

vivado_read_ila(<a href="#vivado_read_ila-name">name</a>, <a href="#vivado_read_ila-deps">deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_read_ila-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_read_ila-deps"></a>deps |  The list of deps containing bitstream/probes code   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


