<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado place and route2 rule.

<a id="vivado_place_and_route2"></a>

## vivado_place_and_route2

<pre>
load("@rules_vivado//internal:vivado_place_and_route2.bzl", "vivado_place_and_route2")

vivado_place_and_route2(<a href="#vivado_place_and_route2-name">name</a>, <a href="#vivado_place_and_route2-env">env</a>, <a href="#vivado_place_and_route2-mount">mount</a>, <a href="#vivado_place_and_route2-synthesis">synthesis</a>, <a href="#vivado_place_and_route2-xdcs">xdcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_place_and_route2-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_place_and_route2-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_place_and_route2-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_place_and_route2-synthesis"></a>synthesis |  The mandatory synth2 target to use   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="vivado_place_and_route2-xdcs"></a>xdcs |  Constraint files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


