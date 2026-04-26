<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado program device rule.

<a id="vivado_program_device"></a>

## vivado_program_device

<pre>
load("@rules_vivado//internal:vivado_program_device.bzl", "vivado_program_device")

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


