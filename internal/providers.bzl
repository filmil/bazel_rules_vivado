
VivadoLibraryProvider = provider(
    "A library of files used for vivado",
    fields = {
        "name": "The library name",
        "files": "The list of files comprising this library",
        "hdrs": "The list of headers in this library",
        "includes": "The list of include dirs in this library.",
        "deps": "A depset of other providers",
        "deps_names": "A depset of library names contained in `deps`",
        "library_dir": "A Vivado compiled library directory",
        "unisims_libs": "A boolean",
    }
)


VivadoGenProvider = provider(
  "Information about generated vivado files",
  fields = {
    "sources": "The list of the module's source files",
    "deps": "Libraries",
    "headers": "A list of header files. " +
      " Headers are present in the sandbox, but not on the command line",
    "constraints": "The list of constraints files to use",
    "include_dirs": "A list of include directories for the code at hand",
    "xpr_tcl_script": "The TCL script used by vivado to generate a project file",
    "synth_tcl_script": "The TCL script used to start synthesis",
    "pnr_tcl_script": "The TCL script used to start place and route",
    "pgm_tcl_script": "The TCL script used to start programming the device",
    "xpr_file": "The generated Vivado project file",
    "top_level": "The top level entity to process",
    "project_name": "The name of the project, after the target",
    "xpr_gen_output_dir": "The output directory from the xpr_gen step",
    "part": "The part designator that is being targeted in this project",
  },
)


VivadoSynthProvider = provider(
  "Information about the synthesis step",
  fields = {
    "synth_output_dir": "",
    # It seems that Vivado wants to write into it.
    "synth_xpr_file": "The XPR file after synthesis",
    "synth_dcp_file": "The DCP file of synthesis step"
  },
)


VivadoBitstreamProvider = provider(
  "Information about the bitstream",
  fields = {
    "bitstream": "The bitstream to program into the FPGA",
  },
)

