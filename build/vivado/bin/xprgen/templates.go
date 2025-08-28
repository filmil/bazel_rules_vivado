package main

import "text/template"

var (
	// The synthesis TCL script.
	syntTpl = template.Must(template.New("synth").Parse(
		`# GENERATED FILE, DO NOT EDIT
# Project synthesis script
# Project name: "{{.Project}}"
# PWD:          "{{ .PWD }}"
# XPR path:     "{{ .OutXpr }}"

launch_runs synth_1
wait_on_run synth_1
exit [regexp -nocase -- {synth_design (error|failed)} [get_property STATUS [get_runs synth_1]] match]

# end
`))

	// The TCL script generating project file.
	xprTpl = template.Must(template.New("xpr").Parse(
		`# GENERATED FILE, DO NOT EDIT
# Project TCL file
# Project name: "{{ .Project }}"
# PWD:          "{{ .PWD }}"
# XPR path:     "{{ .OutXpr }}"

create_project {{.Project}} -force

# Verilog Properties
{{$fileset := .Fileset -}}
{{- range .VerilogProperties }}
set_property verilog_define {{"{"}} {{- . -}} {{"}"}} [get_filesets {{ $fileset }} ]
{{end}}

# SystemVerilog files
# Ordering is important.
{{- range .SystemVerilogFiles}}
read_verilog {{with .Library }} -library {{ . }} {{- end}}  -sv {{"{"}} {{- .Name -}} {{"}"}}
{{- end}}
# end: verilog files

# Verilog files
# Ordering is important.
{{- range .VerilogFiles}}
read_verilog {{with .Library }} -library {{ . }} {{- end}} {{"{"}} {{- .Name -}} {{"}"}}
{{- end}}
# end: verilog files

# Verilog headers
# Ordering is important.
{{- range .VerilogHeaders}}
read_verilog {{with .Library }} -library {{ . }} {{- end}} -sv {{"{"}} {{- .Name -}} {{"}"}}
{{- end}}

# VHDL files
# Ordering is important.
{{- range .VHDLFiles}}
read_vhdl -vhdl2008 {{with .Library }} -library {{ . }} {{- end}} {{"{"}} {{- .Name -}} {{"}"}}
{{- end}}
# end: VHDL files

# Verilog includes
set_property include_dirs [list {{range .VerilogIncludeDirs}} {{ . }} {{- end -}}] [get_filesets {{ $fileset }}]

# Constraints files
# Ordering is important here, too.
{{- range .XDCFiles}}
read_xdc {{"{"}} {{- . -}} {{"}"}}
{{- end}}
# end: constraints files

# Other files.
{{- range .OtherFiles}}
add_files -norecurse {{ . }}
{{- end}}
# end: constraints files

{{- if .Part}}
set_property part {{ .Part }} [current_project]
{{- end}}

set_property top {{ .Top }} [current_fileset]
set_property source_mgmt_mode None [current_project]

# end
`))

	// The TCL script for bitstream generation.
	pnrTpl = template.Must(template.New("pnr").Parse(
		`# GENERATED FILE, DO NOT EDIT
# Project TCL file
# Project name: "{{ .Project }}"
# PWD:          "{{ .PWD }}"
# XPR path:     "{{ .OutXpr }}"

set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

if { [get_property PROGRESS [get_runs impl_1]] != "100%"} {
  launch_runs synth_1 -quiet

  launch_runs impl_1 -to_step write_bitstream
  wait_on_run impl_1
  puts "Bitstream generation completed"
} else {
  puts "Bitstream generation already complete"
}

if { [get_property PROGRESS [get_runs impl_1]] != "100%"} {
   puts "ERROR: Implementation and bitstream generation step failed."
   exit 1
}

set vivadoDefaultBitstreamFile [ get_property DIRECTORY [current_run] ]/[ get_property top [current_fileset] ].bit
file copy -force $vivadoDefaultBitstreamFile [pwd]/[current_project].bit


# end
`))
)
