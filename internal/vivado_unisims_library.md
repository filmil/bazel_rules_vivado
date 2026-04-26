<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado unisims library rule.

<a id="vivado_unisims_library"></a>

## vivado_unisims_library

<pre>
load("@rules_vivado//internal:vivado_unisims_library.bzl", "vivado_unisims_library")

vivado_unisims_library(<a href="#vivado_unisims_library-name">name</a>, <a href="#vivado_unisims_library-env">env</a>, <a href="#vivado_unisims_library-export_libraries">export_libraries</a>, <a href="#vivado_unisims_library-family">family</a>, <a href="#vivado_unisims_library-force">force</a>, <a href="#vivado_unisims_library-language">language</a>, <a href="#vivado_unisims_library-libraries">libraries</a>, <a href="#vivado_unisims_library-mount">mount</a>,
                       <a href="#vivado_unisims_library-no_ip_compile">no_ip_compile</a>, <a href="#vivado_unisims_library-no_systemc_compile">no_systemc_compile</a>, <a href="#vivado_unisims_library-quiet">quiet</a>, <a href="#vivado_unisims_library-simulator">simulator</a>, <a href="#vivado_unisims_library-skip_libraries">skip_libraries</a>, <a href="#vivado_unisims_library-template">template</a>,
                       <a href="#vivado_unisims_library-verbose">verbose</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_unisims_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_unisims_library-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_unisims_library-export_libraries"></a>export_libraries |  The libraries to make available to users.   | List of strings | optional |  `["unisim", "unimacro", "unifast"]`  |
| <a id="vivado_unisims_library-family"></a>family |  The device family to compile the library for.   | String | optional |  `"artix7"`  |
| <a id="vivado_unisims_library-force"></a>force |  Whether to force compilation.   | Boolean | optional |  `False`  |
| <a id="vivado_unisims_library-language"></a>language |  The language to compile for: vhdl\|verilog\|all   | String | optional |  `"vhdl"`  |
| <a id="vivado_unisims_library-libraries"></a>libraries |  The libraries to compile: unisim\|simprim\|...\|all   | List of strings | optional |  `["unisim"]`  |
| <a id="vivado_unisims_library-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_unisims_library-no_ip_compile"></a>no_ip_compile |  Whether to skip IP compile.   | Boolean | optional |  `False`  |
| <a id="vivado_unisims_library-no_systemc_compile"></a>no_systemc_compile |  Whether to skip SystemC compile.   | Boolean | optional |  `False`  |
| <a id="vivado_unisims_library-quiet"></a>quiet |  Whether to be quiet.   | Boolean | optional |  `False`  |
| <a id="vivado_unisims_library-simulator"></a>simulator |  Name of the top level entity to simulate   | String | optional |  `"xsim"`  |
| <a id="vivado_unisims_library-skip_libraries"></a>skip_libraries |  The list of libraries to skip.   | List of strings | optional |  `[]`  |
| <a id="vivado_unisims_library-template"></a>template |  The template for the compile_simlib script.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@rules_vivado//build/vivado:compile_simlib_tcl_template"`  |
| <a id="vivado_unisims_library-verbose"></a>verbose |  Whether to be verbose.   | Boolean | optional |  `False`  |


