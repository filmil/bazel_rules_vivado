<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado generics macro.

<a id="vivado_generics"></a>

## vivado_generics

<pre>
load("@rules_vivado//internal:vivado_generics.bzl", "vivado_generics")

vivado_generics(<a href="#vivado_generics-name">name</a>, <a href="#vivado_generics-verilog_top">verilog_top</a>, <a href="#vivado_generics-vhdl_top">vhdl_top</a>, <a href="#vivado_generics-params">params</a>, <a href="#vivado_generics-generics">generics</a>, <a href="#vivado_generics-data">data</a>, <a href="#vivado_generics-synth">synth</a>)
</pre>

Generates TCL scripts for generics/parameters.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="vivado_generics-name"></a>name |  Target name.   |  none |
| <a id="vivado_generics-verilog_top"></a>verilog_top |  Verilog top entity.   |  `None` |
| <a id="vivado_generics-vhdl_top"></a>vhdl_top |  VHDL top entity.   |  `None` |
| <a id="vivado_generics-params"></a>params |  Dictionary of parameters.   |  `{}` |
| <a id="vivado_generics-generics"></a>generics |  Dictionary of generics.   |  `{}` |
| <a id="vivado_generics-data"></a>data |  Data targets.   |  `None` |
| <a id="vivado_generics-synth"></a>synth |  Synthesis target.   |  `None` |


