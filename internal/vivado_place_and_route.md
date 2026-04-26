<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado place and route rule.

<a id="vivado_place_and_route"></a>

## vivado_place_and_route

<pre>
load("@rules_vivado//internal:vivado_place_and_route.bzl", "vivado_place_and_route")

vivado_place_and_route(<a href="#vivado_place_and_route-name">name</a>, <a href="#vivado_place_and_route-env">env</a>, <a href="#vivado_place_and_route-mount">mount</a>, <a href="#vivado_place_and_route-synthesis">synthesis</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_place_and_route-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_place_and_route-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_place_and_route-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_place_and_route-synthesis"></a>synthesis |  The vivado synthesis to place and route   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


