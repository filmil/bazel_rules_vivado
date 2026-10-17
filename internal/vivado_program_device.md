<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado program device rule.

<a id="vivado_program_device"></a>

## vivado_program_device

<pre>
load("@rules_vivado//internal:vivado_program_device.bzl", "vivado_program_device")

vivado_program_device(<a href="#vivado_program_device-name">name</a>, <a href="#vivado_program_device-deps">deps</a>, <a href="#vivado_program_device-data">data</a>, <a href="#vivado_program_device-prog_daemon">prog_daemon</a>, <a href="#vivado_program_device-prog_daemon_args">prog_daemon_args</a>)
</pre>

Loads a bitstream into the FPGA's volatile configuration memory.

`bazel run` the target. It connects to a hw_server and programs the
bitstream of the target in `deps`, unless `--bitfile` names another.

Flags:

- `--hostport`: the hw_server, often `localhost:3122`. Required.
- `--device`: the hardware target.
- `--bitfile`: a bitstream to program in place of the target's own, such
  as one that another session already built and checked. A relative path
  is relative to where `bazel run` was started. It is required when the
  target has no `deps`, which lets one target program bitstreams that
  were built elsewhere, without running place and route. A target with
  `deps` still builds its own bitstream when it is run, `--bitfile` or
  not, since that bitstream is among its runfiles.
- `--sha256`: the SHA-256 that the bitstream must have, in hex. When the
  file's differs, the device is not programmed. It checks the `--bitfile`
  file when there is one, and the target's own bitstream otherwise.

The script refuses a file that does not start as a Xilinx `.bit` file
does, such as the placeholder that `vivado_place_and_route2` writes for a
failed `write_bitstream`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_program_device-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_program_device-deps"></a>deps |  The target whose bitstream to program. Give one: of several, only the last is used. Without one, `--bitfile` is required when the target is run.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_program_device-data"></a>data |  The list of dependencies to expand   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_program_device-prog_daemon"></a>prog_daemon |  The binary to start before programming   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="vivado_program_device-prog_daemon_args"></a>prog_daemon_args |  The args to give to prog_daemon, subject to make var substitution   | List of strings | optional |  `[]`  |


