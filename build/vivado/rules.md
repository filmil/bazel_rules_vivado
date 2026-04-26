<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado rules for Bazel.

<a id="vivado_gui"></a>

## vivado_gui

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_gui")

vivado_gui(<a href="#vivado_gui-name">name</a>, <a href="#vivado_gui-env">env</a>, <a href="#vivado_gui-mount">mount</a>, <a href="#vivado_gui-script">script</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_gui-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_gui-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_gui-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_gui-script"></a>script |  Optional TCL script to run on startup.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="vivado_ip"></a>

## vivado_ip

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_ip")

vivado_ip(<a href="#vivado_ip-name">name</a>, <a href="#vivado_ip-config">config</a>, <a href="#vivado_ip-env">env</a>, <a href="#vivado_ip-module_name">module_name</a>, <a href="#vivado_ip-mount">mount</a>, <a href="#vivado_ip-part">part</a>, <a href="#vivado_ip-vlnv">vlnv</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_ip-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_ip-config"></a>config |  Configuration properties for the IP.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_ip-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_ip-module_name"></a>module_name |  The name of the IP module. Defaults to target name.   | String | optional |  `""`  |
| <a id="vivado_ip-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_ip-part"></a>part |  The target FPGA part.   | String | required |  |
| <a id="vivado_ip-vlnv"></a>vlnv |  The VLNV of the IP.   | String | required |  |


<a id="vivado_library"></a>

## vivado_library

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_library")

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


<a id="vivado_place_and_route"></a>

## vivado_place_and_route

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_place_and_route")

vivado_place_and_route(<a href="#vivado_place_and_route-name">name</a>, <a href="#vivado_place_and_route-env">env</a>, <a href="#vivado_place_and_route-mount">mount</a>, <a href="#vivado_place_and_route-synthesis">synthesis</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_place_and_route-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_place_and_route-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_place_and_route-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_place_and_route-synthesis"></a>synthesis |  The vivado synthesis to place and route   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="vivado_place_and_route2"></a>

## vivado_place_and_route2

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_place_and_route2")

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


<a id="vivado_program_device"></a>

## vivado_program_device

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_program_device")

vivado_program_device(<a href="#vivado_program_device-name">name</a>, <a href="#vivado_program_device-deps">deps</a>, <a href="#vivado_program_device-data">data</a>, <a href="#vivado_program_device-prog_daemon">prog_daemon</a>, <a href="#vivado_program_device-prog_daemon_args">prog_daemon_args</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_program_device-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_program_device-deps"></a>deps |  The list of deps containing bitstream code   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_program_device-data"></a>data |  The list of dependencies to expand   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_program_device-prog_daemon"></a>prog_daemon |  The binary to start before programming   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="vivado_program_device-prog_daemon_args"></a>prog_daemon_args |  The args to give to prog_daemon, subject to make var substitution   | List of strings | optional |  `[]`  |


<a id="vivado_project"></a>

## vivado_project

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_project")

vivado_project(<a href="#vivado_project-name">name</a>, <a href="#vivado_project-deps">deps</a>, <a href="#vivado_project-srcs">srcs</a>, <a href="#vivado_project-hdrs">hdrs</a>, <a href="#vivado_project-defines">defines</a>, <a href="#vivado_project-env">env</a>, <a href="#vivado_project-include_dirs">include_dirs</a>, <a href="#vivado_project-mount">mount</a>, <a href="#vivado_project-part">part</a>, <a href="#vivado_project-top_level">top_level</a>, <a href="#vivado_project-xdcs">xdcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_project-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_project-deps"></a>deps |  The list of library dependencies   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_project-srcs"></a>srcs |  A list of source files.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_project-hdrs"></a>hdrs |  A list of header files.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_project-defines"></a>defines |  A list of defines.   | List of strings | optional |  `[]`  |
| <a id="vivado_project-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_project-include_dirs"></a>include_dirs |  A list of include directories.   | List of strings | optional |  `[]`  |
| <a id="vivado_project-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_project-part"></a>part |  The part that is targeted by this project   | String | required |  |
| <a id="vivado_project-top_level"></a>top_level |  Top level entity name   | String | required |  |
| <a id="vivado_project-xdcs"></a>xdcs |  A list of constraints files to use.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="vivado_repl"></a>

## vivado_repl

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_repl")

vivado_repl(<a href="#vivado_repl-name">name</a>, <a href="#vivado_repl-env">env</a>, <a href="#vivado_repl-mount">mount</a>, <a href="#vivado_repl-script">script</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_repl-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_repl-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_repl-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_repl-script"></a>script |  Optional TCL script to run on startup.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="vivado_simulation"></a>

## vivado_simulation

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_simulation")

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


<a id="vivado_synthesis"></a>

## vivado_synthesis

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_synthesis")

vivado_synthesis(<a href="#vivado_synthesis-name">name</a>, <a href="#vivado_synthesis-env">env</a>, <a href="#vivado_synthesis-mount">mount</a>, <a href="#vivado_synthesis-project">project</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_synthesis-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_synthesis-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis-project"></a>project |  The Vivado project to work on   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="vivado_synthesis2"></a>

## vivado_synthesis2

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_synthesis2")

vivado_synthesis2(<a href="#vivado_synthesis2-name">name</a>, <a href="#vivado_synthesis2-deps">deps</a>, <a href="#vivado_synthesis2-srcs">srcs</a>, <a href="#vivado_synthesis2-data">data</a>, <a href="#vivado_synthesis2-hdrs">hdrs</a>, <a href="#vivado_synthesis2-defines">defines</a>, <a href="#vivado_synthesis2-env">env</a>, <a href="#vivado_synthesis2-generics">generics</a>, <a href="#vivado_synthesis2-include_dirs">include_dirs</a>, <a href="#vivado_synthesis2-mount">mount</a>, <a href="#vivado_synthesis2-part">part</a>,
                  <a href="#vivado_synthesis2-top">top</a>, <a href="#vivado_synthesis2-xdcs">xdcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_synthesis2-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_synthesis2-deps"></a>deps |  The sources for the libraries   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_synthesis2-srcs"></a>srcs |  The sources for the `work` library   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_synthesis2-data"></a>data |  Other data   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_synthesis2-hdrs"></a>hdrs |  The headers for the `work` library if verilog   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_synthesis2-defines"></a>defines |  A dictionary of defines.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis2-env"></a>env |  A dictionary of env variables to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis2-generics"></a>generics |  A dictionary of generics.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis2-include_dirs"></a>include_dirs |  A list of include directories.   | List of strings | optional |  `[]`  |
| <a id="vivado_synthesis2-mount"></a>mount |  A dictionary of mounts to define for the run.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="vivado_synthesis2-part"></a>part |  The part that is targeted by this project   | String | required |  |
| <a id="vivado_synthesis2-top"></a>top |  Mandatory name of the top level entity   | String | required |  |
| <a id="vivado_synthesis2-xdcs"></a>xdcs |  Constraint files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="vivado_unisims_library"></a>

## vivado_unisims_library

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_unisims_library")

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


<a id="vivado_generics"></a>

## vivado_generics

<pre>
load("@rules_vivado//build/vivado:rules.bzl", "vivado_generics")

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


