<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado view rule.

<a id="vivado_view"></a>

## vivado_view

<pre>
load("@rules_vivado//internal:vivado_view.bzl", "vivado_view")

vivado_view(<a href="#vivado_view-name">name</a>, <a href="#vivado_view-data">data</a>, <a href="#vivado_view-dep">dep</a>, <a href="#vivado_view-env">env</a>, <a href="#vivado_view-mount">mount</a>)
</pre>

Opens a Vivado simulator GUI (xsim) for a generated waveform database (wdb) file.

Example:
```bzl
load("@bazel_rules_vivado//build/vivado:rules.bzl", "vivado_simulation", "vivado_view")

vivado_simulation(
    name = "my_simulation",
    top = "my_top_module",
    # ...
)

vivado_view(
    name = "my_simulation_view",
    dep = ":my_simulation",
    data = ["//path/to/my:custom_waveform_config.wcfg"],
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_view-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_view-data"></a>data |  A list of data targets to pass into the sandbox.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_view-dep"></a>dep |  The dependency that generates the wdb file (e.g. vivado_simulation).   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="vivado_view-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_view-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |


