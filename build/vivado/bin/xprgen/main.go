// xprgen generates a Vivado (fka Xilinx) project file.
//
// The project file is the basis on which Vivado tools operate,
// so though it's weird from the perspective of software compilation
// tools, we're pretty much stuck with it.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path"
	"strings"
	"text/template"
)

const (
	SystemVerilogExtension = ".sv"
	VerilogExtension       = ".v"
	VHDLExtension1         = ".vhd"
	VHDLExtension2         = ".vhdl"
)

type XPRBinding struct {
	// Project name.
	Project string
	// Fileset name.
	Fileset string
	// Top entity name.
	Top string
	// Verilog properties to set.
	VerilogProperties []string

	// The list of pure Verilog files to load.
	VerilogFiles []FileLib
	// The list of SystemVerilog files to load.
	SystemVerilogFiles []FileLib
	// The list of SystemVerilog headers to load.
	VerilogHeaders []string
	// VerilogIncludeDirs is a list of include dirs to load.
	VerilogIncludeDirs []string
	// VHDLFiles is a list of VHDL files to load.
	VHDLFiles []FileLib
	// XDCFiles is a list of constraints (.xdc files) to use.
	XDCFiles []string
	// PWD is the working directory.
	PWD string
	// OutXpr is the name of the Vivado project file (.xpr) that will be generated.
	OutXpr string
	// Part is the designator of the FPGA part to be programmed.
	// For example, "xc7a200tfbg484-2"
	Part string
}

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

# SystemVerilog files
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
read_vhdl {{with .Library }} -library {{ . }} {{- end}} {{"{"}} {{- .Name -}} {{"}"}}
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

var _ flag.Value = (*RepeatedString)(nil)

type RepeatedString struct {
	values []string
}

func (s RepeatedString) Empty() bool {
	return len(s.values) == 0
}

func (s *RepeatedString) Set(v string) error {
	s.values = append(s.values, v)
	return nil
}

func (s *RepeatedString) String() string {
	return strings.Join(s.values, ",")
}

func WriteFile(fn string, tpl *template.Template, xpr *XPRBinding) error {
	if fn == "" {
		return nil
	}
	f, err := os.Create(fn)
	defer func() {
		err := f.Close()
		if err != nil {
			fmt.Printf("WARN: error while closing: %v: %v", fn, err)
		}
	}()
	if err != nil {
		log.Fatalf("could not create: %v: %v", fn, err)
	}
	if err := tpl.Execute(f, xpr); err != nil {
		log.Fatalf("error while writing output: %v", err)
	}

	return nil
}

type FileLib struct {
	// A file name.
	Name string
	// If empty, the library is "work" or whatever "current" is.
	Library string
}

// AppendTo appends `fl` into one of the typed file lists.
func AppendTo(systemVerilogFiles, verilogFiles, VHDLFiles *[]FileLib, fl FileLib) error {
	if fl.Name == "" {
		return fmt.Errorf("no file name in %+v", fl)
	}
	if strings.HasSuffix(fl.Name, SystemVerilogExtension) {
		*systemVerilogFiles = append(*systemVerilogFiles, fl)
	}
	if strings.HasSuffix(fl.Name, VerilogExtension) {
		*verilogFiles = append(*verilogFiles, fl)
	}
	if strings.HasSuffix(fl.Name, VHDLExtension1) || strings.HasSuffix(fl.Name, VHDLExtension2) {
		*VHDLFiles = append(*VHDLFiles, fl)
	}
	return nil
}

func main() {
	p := path.Base(os.Args[0])
	log.SetPrefix(fmt.Sprintf("%v: ", p))

	var (
		sources, headers, includeDirs, defines  RepeatedString
		projectName, filesetName, topName       string
		dirDepth                                int
		xprFileName, synthFileName, pnrFileName string
		xdcFiles                                RepeatedString
		part                                    string
		libraryFiles                            RepeatedString
	)

	// Vivado is unable to create a project in any directory other than its
	// PWD. So we need to account for that when generating.
	flag.IntVar(&dirDepth, "dir-depth", 0, "The depth of the directory structure")

	flag.StringVar(&xprFileName, "out-xpr", "", "output XPR file")
	flag.StringVar(&synthFileName, "out-synth", "", "output synth file")
	flag.StringVar(&pnrFileName, "out-pnr", "", "output synth file")

	flag.StringVar(&projectName, "project-name", "", "the name of the top-level project")
	// Vivado requires this value, not sure if its name makes a difference.
	flag.StringVar(&filesetName, "fileset-name", "sources_1", "the name of the file set to create")
	flag.StringVar(&topName, "top-name", "", "the name of the top level entity")

	flag.Var(&sources, "source", "list of source files")
	flag.Var(&xdcFiles, "constraints", "lists of constraint files [.xdc]")
	flag.Var(&headers, "header", "list of header files")
	flag.Var(&includeDirs, "include-dir", "list of include directories")
	flag.Var(&defines, "define", "list of include directories")
	flag.Var(&libraryFiles, "library-file", "each is: library=file")
	flag.StringVar(&part, "part", "", "The FPGA part to use for synthesis")
	flag.Parse()

	if part == "" {
		log.Fatalf("flag --part=... is required")
	}
	if projectName == "" {
		log.Fatalf("flag --project-name=... is required")
	}
	if topName == "" {
		log.Fatalf("flag --top-name=... is required")
	}
	if sources.Empty() {
		log.Fatalf("at least one --source arg is required")
	}

	var (
		pPaths []string
	)
	for i := 0; i < dirDepth; i++ {
		pPaths = append(pPaths, "..")
	}
	ppath := strings.Join(pPaths, "/")

	var (
		verilogFiles       []FileLib
		systemVerilogFiles []FileLib
		VHDLFiles          []FileLib
	)

	for _, v := range libraryFiles.values {
		s := strings.Split(v, "=")
		if err := AppendTo(&systemVerilogFiles, &verilogFiles, &VHDLFiles, FileLib{Name: s[1], Library: s[0]}); err != nil {
			log.Fatalf("while classifying: %v: %v", v, err)
		}
	}

	// Sort the different program files into their own file type lists. Order
	// is significant.
	for _, v := range sources.values {
		if err := AppendTo(&systemVerilogFiles, &verilogFiles, &VHDLFiles, FileLib{Name: v}); err != nil {
			log.Fatalf("while classifying: %v: %v", v, err)
		}
	}

	var vDirs []string
	for _, v := range includeDirs.values {
		vDirs = append(vDirs, path.Join(ppath, v))
	}
	for _, f := range headers.values {
		vDirs = append(vDirs, path.Join(ppath, path.Dir(path.Clean(f))))
	}

	pwd, err := os.Getwd()
	if err != nil {
		log.Fatalf("can not get PWD: %v", err)
	}
	xpr := XPRBinding{
		Project:            projectName,
		Fileset:            filesetName,
		Top:                topName,
		VerilogProperties:  defines.values,
		SystemVerilogFiles: systemVerilogFiles,
		VerilogFiles:       verilogFiles,
		VHDLFiles:          VHDLFiles,
		VerilogHeaders:     headers.values,
		VerilogIncludeDirs: vDirs,
		XDCFiles:           xdcFiles.values,
		PWD:                pwd,
		OutXpr:             xprFileName,
		Part:               part,
	}

	if err := WriteFile(xprFileName, xprTpl, &xpr); err != nil {
		log.Fatalf("while writing XPR file: %v: %v", xprFileName, err)
	}
	if err := WriteFile(synthFileName, syntTpl, &xpr); err != nil {
		log.Fatalf("while writing synth file: %v: %v", synthFileName, err)
	}
	if err := WriteFile(pnrFileName, pnrTpl, &xpr); err != nil {
		log.Fatalf("while writing PNR file: %v: %v", pnrFileName, err)
	}
}
