<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado test rule.

<a id="vivado_test"></a>

## vivado_test

<pre>
load("@rules_vivado//internal:vivado_test.bzl", "vivado_test")

vivado_test(<a href="#vivado_test-name">name</a>, <a href="#vivado_test-data">data</a>, <a href="#vivado_test-config">config</a>, <a href="#vivado_test-custom_tcl_script">custom_tcl_script</a>, <a href="#vivado_test-defines">defines</a>, <a href="#vivado_test-env">env</a>, <a href="#vivado_test-extra_modules">extra_modules</a>, <a href="#vivado_test-generic_tops">generic_tops</a>,
            <a href="#vivado_test-library">library</a>, <a href="#vivado_test-mount">mount</a>, <a href="#vivado_test-template">template</a>, <a href="#vivado_test-top">top</a>, <a href="#vivado_test-xelab_args">xelab_args</a>, <a href="#vivado_test-xelab_relaxed">xelab_relaxed</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_test-data"></a>data |  A list of data targets.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_test-config"></a>config |  If specified, the said named configuration will be selected (VHDL)   | String | optional |  `""`  |
| <a id="vivado_test-custom_tcl_script"></a>custom_tcl_script |  Custom TCL script to run simulation with   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="vivado_test-defines"></a>defines |  The list of key-to-value mappings to apply to the compilation   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_test-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_test-extra_modules"></a>extra_modules |  Names of additional modules to co-simulate   | List of strings | optional |  `[]`  |
| <a id="vivado_test-generic_tops"></a>generic_tops |  The list of key-to-value mappings to apply to the compilation   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_test-library"></a>library |  The library to run the simulation from   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="vivado_test-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_test-template"></a>template |  The TCL template to run.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_vivado//build/vivado:xsim.tcl.template"`  |
| <a id="vivado_test-top"></a>top |  Name of the top level entity to simulate   | String | optional |  `""`  |
| <a id="vivado_test-xelab_args"></a>xelab_args |  Custom args to elaboration step   | List of strings | optional |  `[]`  |
| <a id="vivado_test-xelab_relaxed"></a>xelab_relaxed |  Relax HDL checks, sometimes needed for Verilog modules   | Boolean | optional |  `False`  |


