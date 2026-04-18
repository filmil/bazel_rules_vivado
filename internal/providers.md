<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Defines providers used in Vivado rules.

<a id="VivadoBitstreamProvider"></a>

## VivadoBitstreamProvider

<pre>
load("@rules_vivado//internal:providers.bzl", "VivadoBitstreamProvider")

VivadoBitstreamProvider(<a href="#VivadoBitstreamProvider-bitstream">bitstream</a>)
</pre>

Information about the bitstream

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="VivadoBitstreamProvider-bitstream"></a>bitstream |  The bitstream to program into the FPGA    |


<a id="VivadoGenProvider"></a>

## VivadoGenProvider

<pre>
load("@rules_vivado//internal:providers.bzl", "VivadoGenProvider")

VivadoGenProvider(<a href="#VivadoGenProvider-sources">sources</a>, <a href="#VivadoGenProvider-deps">deps</a>, <a href="#VivadoGenProvider-headers">headers</a>, <a href="#VivadoGenProvider-constraints">constraints</a>, <a href="#VivadoGenProvider-include_dirs">include_dirs</a>, <a href="#VivadoGenProvider-xpr_tcl_script">xpr_tcl_script</a>,
                  <a href="#VivadoGenProvider-synth_tcl_script">synth_tcl_script</a>, <a href="#VivadoGenProvider-pnr_tcl_script">pnr_tcl_script</a>, <a href="#VivadoGenProvider-pgm_tcl_script">pgm_tcl_script</a>, <a href="#VivadoGenProvider-xpr_file">xpr_file</a>, <a href="#VivadoGenProvider-top_level">top_level</a>, <a href="#VivadoGenProvider-project_name">project_name</a>,
                  <a href="#VivadoGenProvider-xpr_gen_output_dir">xpr_gen_output_dir</a>, <a href="#VivadoGenProvider-part">part</a>)
</pre>

Information about generated vivado files

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="VivadoGenProvider-sources"></a>sources |  The list of the module's source files    |
| <a id="VivadoGenProvider-deps"></a>deps |  The list of library dependencies    |
| <a id="VivadoGenProvider-headers"></a>headers |  A list of header files.  Headers are present in the sandbox, but not on the command line    |
| <a id="VivadoGenProvider-constraints"></a>constraints |  The list of constraints files to use    |
| <a id="VivadoGenProvider-include_dirs"></a>include_dirs |  A list of include directories for the code at hand    |
| <a id="VivadoGenProvider-xpr_tcl_script"></a>xpr_tcl_script |  The TCL script used by vivado to generate a project file    |
| <a id="VivadoGenProvider-synth_tcl_script"></a>synth_tcl_script |  The TCL script used to start synthesis    |
| <a id="VivadoGenProvider-pnr_tcl_script"></a>pnr_tcl_script |  The TCL script used to start place and route    |
| <a id="VivadoGenProvider-pgm_tcl_script"></a>pgm_tcl_script |  The TCL script used to start programming the device    |
| <a id="VivadoGenProvider-xpr_file"></a>xpr_file |  The generated Vivado project file    |
| <a id="VivadoGenProvider-top_level"></a>top_level |  The top level entity to process    |
| <a id="VivadoGenProvider-project_name"></a>project_name |  The name of the project, after the target    |
| <a id="VivadoGenProvider-xpr_gen_output_dir"></a>xpr_gen_output_dir |  The output directory from the xpr_gen step    |
| <a id="VivadoGenProvider-part"></a>part |  The part designator that is being targeted in this project    |


<a id="VivadoLibraryProvider"></a>

## VivadoLibraryProvider

<pre>
load("@rules_vivado//internal:providers.bzl", "VivadoLibraryProvider")

VivadoLibraryProvider(<a href="#VivadoLibraryProvider-name">name</a>, <a href="#VivadoLibraryProvider-files">files</a>, <a href="#VivadoLibraryProvider-hdrs">hdrs</a>, <a href="#VivadoLibraryProvider-includes">includes</a>, <a href="#VivadoLibraryProvider-deps">deps</a>, <a href="#VivadoLibraryProvider-deps_names">deps_names</a>, <a href="#VivadoLibraryProvider-library_dir">library_dir</a>, <a href="#VivadoLibraryProvider-unisims_libs">unisims_libs</a>)
</pre>

A library of files used for vivado

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="VivadoLibraryProvider-name"></a>name |  The library name    |
| <a id="VivadoLibraryProvider-files"></a>files |  The list of files comprising this library    |
| <a id="VivadoLibraryProvider-hdrs"></a>hdrs |  The list of headers in this library    |
| <a id="VivadoLibraryProvider-includes"></a>includes |  The list of include dirs in this library.    |
| <a id="VivadoLibraryProvider-deps"></a>deps |  A depset of other providers    |
| <a id="VivadoLibraryProvider-deps_names"></a>deps_names |  A depset of library names contained in `deps`    |
| <a id="VivadoLibraryProvider-library_dir"></a>library_dir |  A Vivado compiled library directory    |
| <a id="VivadoLibraryProvider-unisims_libs"></a>unisims_libs |  A boolean indicating if this library contains UNISIMs    |


<a id="VivadoSynthProvider"></a>

## VivadoSynthProvider

<pre>
load("@rules_vivado//internal:providers.bzl", "VivadoSynthProvider")

VivadoSynthProvider(<a href="#VivadoSynthProvider-synth_output_dir">synth_output_dir</a>, <a href="#VivadoSynthProvider-synth_xpr_file">synth_xpr_file</a>, <a href="#VivadoSynthProvider-synth_dcp_file">synth_dcp_file</a>)
</pre>

Information about the synthesis step

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="VivadoSynthProvider-synth_output_dir"></a>synth_output_dir |  The output directory for the synthesis step    |
| <a id="VivadoSynthProvider-synth_xpr_file"></a>synth_xpr_file |  The XPR file after synthesis    |
| <a id="VivadoSynthProvider-synth_dcp_file"></a>synth_dcp_file |  The DCP file of synthesis step    |
