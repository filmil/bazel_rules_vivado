<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Integrated Logic Analyzer (ILA) core generation macro.

<a id="vivado_ila"></a>

## vivado_ila

<pre>
load("@rules_vivado//internal:vivado_ila.bzl", "vivado_ila")

vivado_ila(<a href="#vivado_ila-name">name</a>, <a href="#vivado_ila-part">part</a>, <a href="#vivado_ila-probe_widths">probe_widths</a>, <a href="#vivado_ila-data_depth">data_depth</a>, <a href="#vivado_ila-enable_storage_qualification">enable_storage_qualification</a>, <a href="#vivado_ila-input_pipe_stages">input_pipe_stages</a>,
           <a href="#vivado_ila-enable_trigger_out">enable_trigger_out</a>, <a href="#vivado_ila-enable_trigger_in">enable_trigger_in</a>, <a href="#vivado_ila-ila_version">ila_version</a>, <a href="#vivado_ila-kwargs">**kwargs</a>)
</pre>

Generates an Integrated Logic Analyzer (ILA) IP core using the vivado_ip rule.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="vivado_ila-name"></a>name |  A unique name for this target.   |  none |
| <a id="vivado_ila-part"></a>part |  The target FPGA part (e.g. "xc7a200tsbg484-1").   |  none |
| <a id="vivado_ila-probe_widths"></a>probe_widths |  List of integers representing the width of each probe. For example: [1, 8, 32] creates 3 probes (PROBE0 width 1, PROBE1 width 8, PROBE2 width 32).   |  none |
| <a id="vivado_ila-data_depth"></a>data_depth |  The sample data depth. Options: 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072.   |  `1024` |
| <a id="vivado_ila-enable_storage_qualification"></a>enable_storage_qualification |  Enable storage qualification (capturing only when a trigger condition is met).   |  `False` |
| <a id="vivado_ila-input_pipe_stages"></a>input_pipe_stages |  Number of input pipeline stages to improve timing closure.   |  `0` |
| <a id="vivado_ila-enable_trigger_out"></a>enable_trigger_out |  Enable trigger output port.   |  `False` |
| <a id="vivado_ila-enable_trigger_in"></a>enable_trigger_in |  Enable trigger input port.   |  `False` |
| <a id="vivado_ila-ila_version"></a>ila_version |  The version of the ILA IP core. Default is "6.2".   |  `"6.2"` |
| <a id="vivado_ila-kwargs"></a>kwargs |  Additional arguments to pass to the underlying vivado_ip target.   |  none |


