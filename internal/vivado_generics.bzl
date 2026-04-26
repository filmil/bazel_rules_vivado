"""Vivado generics macro."""

def vivado_generics(name, verilog_top=None, vhdl_top=None, params={}, generics={}, data=None, synth=None):
    """Generates TCL scripts for generics/parameters.

    Args:
      name: Target name.
      verilog_top: Verilog top entity.
      vhdl_top: VHDL top entity.
      params: Dictionary of parameters.
      generics: Dictionary of generics.
      data: Data targets.
      synth: Synthesis target.
    """
    out_name = "{}.tcl".format(name)
    args = []
    for k, v in params.items():
        args +=  [
            "--param={}={}".format(k, v),
    ]
    if verilog_top:
        args += ["--verilog-top", verilog_top]

    for k, v in generics.items():
        args +=  [
            "--generic={}={}".format(k, v),
    ]
    if vhdl_top:
        args += ["--vhdl-top", vhdl_top]
    native.genrule(
        name=name,
        srcs=data,
        outs = [ out_name ],
        tools = [ Label("@rules_vivado//bin/genparams") ] + data,
        cmd = """$(location @rules_vivado//bin/genparams) {} > $@""".format(" ".join(args)),
    )
