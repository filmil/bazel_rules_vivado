<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado library rule.

<a id="vivado_library"></a>

## vivado_library

<pre>
load("@rules_vivado//internal:vivado_library.bzl", "vivado_library")

vivado_library(<a href="#vivado_library-name">name</a>, <a href="#vivado_library-deps">deps</a>, <a href="#vivado_library-srcs">srcs</a>, <a href="#vivado_library-data">data</a>, <a href="#vivado_library-hdrs">hdrs</a>, <a href="#vivado_library-defines">defines</a>, <a href="#vivado_library-env">env</a>, <a href="#vivado_library-includes">includes</a>, <a href="#vivado_library-library_name">library_name</a>, <a href="#vivado_library-mount">mount</a>, <a href="#vivado_library-standard">standard</a>,
               <a href="#vivado_library-use_glbl">use_glbl</a>, <a href="#vivado_library-vhdl1993">vhdl1993</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_library-deps"></a>deps |  The list of files in this library   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_library-srcs"></a>srcs |  The list of files in this library   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_library-data"></a>data |  The list of target that should be available for compilation.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_library-hdrs"></a>hdrs |  The list of include files in this library   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_library-defines"></a>defines |  The list of key-to-value mappings to apply to the compilation   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_library-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_library-includes"></a>includes |  The list of additional directories to append to the include list   | List of strings | optional |  `[]`  |
| <a id="vivado_library-library_name"></a>library_name |  An optional library name, in the case the target name can not be used for some reason.   | String | optional |  `""`  |
| <a id="vivado_library-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_library-standard"></a>standard |  Specify the language standard to use   | String | optional |  `"2008"`  |
| <a id="vivado_library-use_glbl"></a>use_glbl |  Whether to use the global glbl.v.   | Boolean | optional |  `False`  |
| <a id="vivado_library-vhdl1993"></a>vhdl1993 |  Use VHDL-1993 standard else use VHDL-2008   | Boolean | optional |  `False`  |


