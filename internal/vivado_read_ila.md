<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Vivado read ILA rule.

<a id="vivado_read_ila"></a>

## vivado_read_ila

<pre>
load("@rules_vivado//internal:vivado_read_ila.bzl", "vivado_read_ila")

vivado_read_ila(<a href="#vivado_read_ila-name">name</a>, <a href="#vivado_read_ila-deps">deps</a>)
</pre>

Captures an ILA core's data into a VCD file.

`bazel run` the target. It connects to a hw_server, loads the probes of
the bitstream in `deps`, runs the ILA core and writes what it captured.

Flags:

- `--hostport`: the hw_server, often `localhost:3122`. Required.
- `--device`: the hardware target.
- `--trigger=probe=value`: compare one probe against a value, for
  example `--trigger=state=eq3'h5`. Repeat it to trigger on several
  probes; probes not named stay don't-care. A bare value, such as
  `--trigger=eq1'b1`, sets every probe, which only works when all the
  probes have the same width.
- `--trigger_file`: a file of `probe value` lines, with `#` comments,
  read before the `--trigger` flags. A relative path is relative to
  where `bazel run` was started.
- `--trigger_position`: the sample of the window at which the trigger
  lands (`CONTROL.TRIGGER_POSITION`).
- `--window_count`: the number of windows the capture depth is split
  into (`CONTROL.WINDOW_COUNT`).
- `--vcd`: the output file, `ila_data.vcd` by default.

A probe may be named with or without its bus range: `addr` and
`addr[34:0]` are the same probe. A name that matches no probe stops the
run and lists the probes of the core.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="vivado_read_ila-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="vivado_read_ila-deps"></a>deps |  The list of deps containing bitstream/probes code   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


