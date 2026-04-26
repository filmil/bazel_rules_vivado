<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado simulation rule.

<a id="vivado_simulation"></a>

## vivado_simulation

<pre>
load("@rules_vivado//internal:vivado_simulation.bzl", "vivado_simulation")

vivado_simulation(<a href="#vivado_simulation-name">name</a>, <a href="#vivado_simulation-data">data</a>, <a href="#vivado_simulation-args">args</a>, <a href="#vivado_simulation-config">config</a>, <a href="#vivado_simulation-custom_tcl_script">custom_tcl_script</a>, <a href="#vivado_simulation-defines">defines</a>, <a href="#vivado_simulation-env">env</a>, <a href="#vivado_simulation-extra_modules">extra_modules</a>,
                  <a href="#vivado_simulation-generic_tops">generic_tops</a>, <a href="#vivado_simulation-library">library</a>, <a href="#vivado_simulation-mount">mount</a>, <a href="#vivado_simulation-template">template</a>, <a href="#vivado_simulation-top">top</a>, <a href="#vivado_simulation-xelab_args">xelab_args</a>, <a href="#vivado_simulation-xelab_relaxed">xelab_relaxed</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_simulation-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_simulation-data"></a>data |  A list of data targets.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_simulation-args"></a>args |  Custom args to xsim   | List of strings | optional |  `[]`  |
| <a id="vivado_simulation-config"></a>config |  If specified, the said named configuration will be selected (VHDL)   | String | optional |  `""`  |
| <a id="vivado_simulation-custom_tcl_script"></a>custom_tcl_script |  Custom TCL script to run simulation with   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="vivado_simulation-defines"></a>defines |  The list of key-to-value mappings to apply to the compilation   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_simulation-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_simulation-extra_modules"></a>extra_modules |  Names of additional modules to co-simulate   | List of strings | optional |  `[]`  |
| <a id="vivado_simulation-generic_tops"></a>generic_tops |  The list of key-to-value mappings to apply to the compilation   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_simulation-library"></a>library |  The library to run the simulation from   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="vivado_simulation-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_simulation-template"></a>template |  The TCL template to run.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_vivado//build/vivado:xsim.tcl.template"`  |
| <a id="vivado_simulation-top"></a>top |  Name of the top level entity to simulate   | String | optional |  `""`  |
| <a id="vivado_simulation-xelab_args"></a>xelab_args |  Custom args to elaboration step   | List of strings | optional |  `[]`  |
| <a id="vivado_simulation-xelab_relaxed"></a>xelab_relaxed |  Relax HDL checks, sometimes needed for Verilog modules   | Boolean | optional |  `False`  |


