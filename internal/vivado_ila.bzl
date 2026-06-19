"""Integrated Logic Analyzer (ILA) core generation macro."""

load("//internal:vivado_ip.bzl", "vivado_ip")

def vivado_ila(
    name,
    part,
    probe_widths,
    data_depth = 1024,
    enable_storage_qualification = False,
    input_pipe_stages = 0,
    enable_trigger_out = False,
    enable_trigger_in = False,
    ila_version = "6.2",
    **kwargs
):
    """Generates an Integrated Logic Analyzer (ILA) IP core using the vivado_ip rule.

    Args:
      name: A unique name for this target.
      part: The target FPGA part (e.g. "xc7a200tsbg484-1").
      probe_widths: List of integers representing the width of each probe.
        For example: [1, 8, 32] creates 3 probes (PROBE0 width 1, PROBE1 width 8, PROBE2 width 32).
      data_depth: The sample data depth. Options: 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072.
      enable_storage_qualification: Enable storage qualification (capturing only when a trigger condition is met).
      input_pipe_stages: Number of input pipeline stages to improve timing closure.
      enable_trigger_out: Enable trigger output port.
      enable_trigger_in: Enable trigger input port.
      ila_version: The version of the ILA IP core. Default is "6.2".
      **kwargs: Additional arguments to pass to the underlying vivado_ip target.
    """
    config = {
        "C_NUM_OF_PROBES": str(len(probe_widths)),
        "C_DATA_DEPTH": str(data_depth),
        "C_EN_STRG_QUAL": "1" if enable_storage_qualification else "0",
        "C_INPUT_PIPE_STAGES": str(input_pipe_stages),
        "C_TRIGOUT_EN": "true" if enable_trigger_out else "false",
        "C_TRIGIN_EN": "true" if enable_trigger_in else "false",
    }

    # Map probe widths dynamically to Vivado keys
    for i, width in enumerate(probe_widths):
        config["C_PROBE{}_WIDTH".format(i)] = str(width)

    # Allow manual overrides/additions via direct config if provided
    if "config" in kwargs:
        config.update(kwargs.pop("config"))

    # Delegate to the fully validated vivado_ip core rule
    vivado_ip(
        name = name,
        vlnv = "xilinx.com:ip:ila:{}".format(ila_version),
        part = part,
        config = config,
        **kwargs
    )
