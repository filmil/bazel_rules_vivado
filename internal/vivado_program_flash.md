<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rule to program a bitstream into a device's non-volatile flash.

The `vivado_program_device` rule loads a bitstream into the FPGA's volatile
configuration SRAM, which is lost on the next power cycle. `vivado_program_flash`
instead writes the design into the board's non-volatile SPI/QSPI configuration
flash so that the FPGA loads the design automatically at power-up -- i.e. it
programs the device "permanently".

It works in two phases:

1. A hermetic build action runs Vivado's `write_cfgmem` to convert the `.bit`
   into a flash image (`.mcs`/`.bin`) for the configured flash part. This needs
   Vivado but no hardware, so it is a normal, cacheable Bazel build action --
   `bazel build` on the target produces the flash image.
2. A generated `bazel run` wrapper connects to a running hardware server and
   erases + writes that image into the device flash via Vivado's
   `create_hw_cfgmem` / `program_hw_cfgmem`. This needs the physical board.

<a id="vivado_program_flash"></a>

## vivado_program_flash

<pre>
load("@rules_vivado//internal:vivado_program_flash.bzl", "vivado_program_flash")

vivado_program_flash(<a href="#vivado_program_flash-name">name</a>, <a href="#vivado_program_flash-deps">deps</a>, <a href="#vivado_program_flash-data">data</a>, <a href="#vivado_program_flash-flash_part">flash_part</a>, <a href="#vivado_program_flash-format">format</a>, <a href="#vivado_program_flash-interface">interface</a>, <a href="#vivado_program_flash-prog_daemon">prog_daemon</a>, <a href="#vivado_program_flash-prog_daemon_args">prog_daemon_args</a>,
                     <a href="#vivado_program_flash-size">size</a>)
</pre>

Programs a bitstream into a device's non-volatile configuration flash (SPI/QSPI) so it loads automatically on power-up. `bazel build` produces the flash image (.mcs/.bin); `bazel run` writes it to the board (requires --hostport and --device).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_program_flash-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_program_flash-deps"></a>deps |  Exactly one target providing the bitstream to flash.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_program_flash-data"></a>data |  The list of dependencies to expand in prog_daemon_args.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="vivado_program_flash-flash_part"></a>flash_part |  The Vivado cfgmem part name of the target flash device, e.g. 'mt25ql256-spi-x1_x2_x4'. Board-specific; see `get_cfgmem_parts` in Vivado.   | String | required |  |
| <a id="vivado_program_flash-format"></a>format |  The flash image format produced by `write_cfgmem`.   | String | optional |  `"mcs"`  |
| <a id="vivado_program_flash-interface"></a>interface |  The flash programming interface, e.g. SPIx1/SPIx2/SPIx4.   | String | optional |  `"SPIx4"`  |
| <a id="vivado_program_flash-prog_daemon"></a>prog_daemon |  Optional binary to start before programming (e.g. a hardware server).   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="vivado_program_flash-prog_daemon_args"></a>prog_daemon_args |  Args for prog_daemon, subject to make var substitution.   | List of strings | optional |  `[]`  |
| <a id="vivado_program_flash-size"></a>size |  The flash capacity in megabytes (MB), passed to `write_cfgmem -size`.   | Integer | required |  |


