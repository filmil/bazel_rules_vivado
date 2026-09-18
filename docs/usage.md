# Usage

## Running Vivado REPL

You can start a Vivado TCL REPL session using Bazel:

```bash
bazel run //build/vivado:repl
```

This will start Vivado in TCL mode within the container, mounting your current workspace.

You can also pass a custom TCL script to be executed upon startup using the `script` attribute:

```python
vivado_repl(
    name = "repl_with_script",
    script = "my_script.tcl",
)
```

## Running Vivado GUI

You can start the Vivado GUI using Bazel:

```bash
bazel run //build/vivado:gui
```

This requires an X11 server running on your host and will forward the X11 socket to the container.

Similarly to the REPL, you can pass a custom TCL script to be executed upon startup:

```python
vivado_gui(
    name = "gui_with_script",
    script = "my_script.tcl",
)
```

## Generating Custom AMD IP

You can generate and configure custom AMD IP blocks and use them as libraries:

```python
vivado_ip(
    name = "clk_wiz_0",
    vlnv = "xilinx.com:ip:clk_wiz:6.0",
    part = "xc7a200tfbg484-2",
    config = {
        "PRIM_SOURCE": "Single_ended_clock_capable_pin",
        "CLKOUT1_REQUESTED_OUT_FREQ": "100.000",
    },
)

# Then use clk_wiz_0 as a dependency in other rules
vivado_simulation(
    name = "sim",
    library = ":my_lib",
    deps = [":clk_wiz_0"],
    top = "tb",
)
```

A configuration Vivado rejects fails the build. Vivado leaves with a
clean exit status whether or not its script got where it was going, so
the generation script checks each step itself, and the action reads the
log as well; the error Vivado printed is shown. The out-of-context
synthesis the script attempts after the sources are generated is best
effort, and its errors do not fail the build: what the rule delivers is
the IP's sources.

`//ip/custom_ip:clk_wiz_rejected` in the integration workspace is such a
configuration, kept so that the failure can be seen.

