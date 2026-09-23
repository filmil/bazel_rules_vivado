<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado IP generation rule.

<a id="vivado_ip"></a>

## vivado_ip

<pre>
load("@rules_vivado//internal:vivado_ip.bzl", "vivado_ip")

vivado_ip(<a href="#vivado_ip-name">name</a>, <a href="#vivado_ip-data">data</a>, <a href="#vivado_ip-config">config</a>, <a href="#vivado_ip-env">env</a>, <a href="#vivado_ip-example_design">example_design</a>, <a href="#vivado_ip-module_name">module_name</a>, <a href="#vivado_ip-mount">mount</a>, <a href="#vivado_ip-part">part</a>, <a href="#vivado_ip-vlnv">vlnv</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_ip-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_ip-data"></a>data |  Files the configuration names: a `config` value of the form `data:<name>` is replaced by the path of the file of that name here, for an IP configured from a file, as MIG is from its project file.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_ip-config"></a>config |  Configuration properties for the IP.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_ip-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_ip-example_design"></a>example_design |  Open the IP's example design as well, and keep its imported sources, the testbench and the models Vivado ships for the IP, under `<name>.ip_gen/example/imports`.   | Boolean | optional |  `False`  |
| <a id="vivado_ip-module_name"></a>module_name |  The name of the IP module. Defaults to target name.   | String | optional |  `""`  |
| <a id="vivado_ip-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_ip-part"></a>part |  The target FPGA part.   | String | required |  |
| <a id="vivado_ip-vlnv"></a>vlnv |  The VLNV of the IP.   | String | required |  |


