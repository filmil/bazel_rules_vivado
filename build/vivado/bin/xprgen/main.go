// xprgen generates a Vivado (fka Xilinx) project file.
//
// The project file is the basis on which Vivado tools operate,
// so though it's weird from the perspective of software compilation
// tools, we're pretty much stuck with it.
package main

import (
	"flag"
	"fmt"
	"io"
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
	// VHDL generics to set
	VHDLGenerics []string
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
	// OtherFiles is a list of generic files to load.
	OtherFiles []FileLib
	// XDCFiles is a list of constraints (.xdc files) to use.
	XDCFiles []string
	// PWD is the working directory.
	PWD string
	// OutXpr is the name of the Vivado project file (.xpr) that will be generated.
	OutXpr string
	// Part is the designator of the FPGA part to be programmed.
	// For example, "xc7a200tfbg484-2"
	Part string
	// VHDLStandard is the standard of language to use, e.g. "2008" (also the
	// default).
	VHDLStandard string
	// LoadDcp file is the checkpoint file for a previous step, if any.
	LoadDcpFile string
	// SaveDcp file is the checkpoint file for this step, if specified.
	SaveDcpFile string
	// BistreamName is an optional name of the bitstream to generate.
	BitstreamName string

	TimingSummaryFile, UtilizationFile, DRCFile string
	SynthFileName, PnrFileName, CustomFileName  string
}

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
func AppendTo(systemVerilogFiles, verilogFiles, VHDLFiles, otherFiles *[]FileLib, fl FileLib) error {
	if fl.Name == "" {
		return fmt.Errorf("no file name in %+v", fl)
	} else if strings.HasSuffix(fl.Name, SystemVerilogExtension) {
		*systemVerilogFiles = append(*systemVerilogFiles, fl)
	} else if strings.HasSuffix(fl.Name, VerilogExtension) {
		*verilogFiles = append(*verilogFiles, fl)
	} else if strings.HasSuffix(fl.Name, VHDLExtension1) || strings.HasSuffix(fl.Name, VHDLExtension2) {
		*VHDLFiles = append(*VHDLFiles, fl)
	} else {
		*otherFiles = append(*otherFiles, fl)
	}
	return nil
}

func main() {
	p := path.Base(os.Args[0])
	log.SetPrefix(fmt.Sprintf("%v: ", p))

	var xpr XPRBinding

	// Vivado is unable to create a project in any directory other than its
	// PWD. So we need to account for that when generating.
	var dirDepth int
	flag.IntVar(&dirDepth, "dir-depth", 0, "The depth of the directory structure")

	flag.StringVar(&xpr.OutXpr, "out-xpr", "", "output XPR file")
	flag.StringVar(&xpr.SynthFileName, "out-synth", "", "output synth file")
	flag.StringVar(&xpr.PnrFileName, "out-pnr", "", "output synth file")

	flag.StringVar(&xpr.Project, "project-name", "", "the name of the top-level project")
	// Vivado requires this value, not sure if its name makes a difference.
	flag.StringVar(&xpr.Fileset, "fileset-name", "sources_1", "the name of the file set to create")
	flag.StringVar(&xpr.Top, "top-name", "", "the name of the top level entity")

	var sources RepeatedString
	flag.Var(&sources, "source", "list of source files")

	var xdcFiles RepeatedString
	flag.Var(&xdcFiles, "constraints", "lists of constraint files [.xdc]")

	var headers RepeatedString
	flag.Var(&headers, "header", "list of header files")

	var includeDirs RepeatedString
	flag.Var(&includeDirs, "include-dir", "list of include directories")

	var libraryFiles RepeatedString
	flag.Var(&libraryFiles, "library-file", "each is: library=file")
	flag.StringVar(&xpr.Part, "part", "", "The FPGA part to use for synthesis")
	flag.StringVar(&xpr.VHDLStandard, "vhdl-standard", "2008", "The VHDL language standard to use")

	flag.StringVar(&xpr.CustomFileName, "custom-filename", "", "Custom file to generate")

	var customTemplateFileName string
	flag.StringVar(&customTemplateFileName, "custom-template", "", "Custom file template")

	flag.StringVar(&xpr.LoadDcpFile, "load-dcp", "", "Input snapshot file")
	flag.StringVar(&xpr.SaveDcpFile, "save-dcp", "", "Output snapshot file")
	flag.StringVar(&xpr.BitstreamName, "bitstream", "", "Output bitstream file")
	flag.StringVar(&xpr.TimingSummaryFile, "timing-report", "", "The file to write the timing report to")
	flag.StringVar(&xpr.UtilizationFile, "utilization-report", "", "The file to write the utilization report to")
	flag.StringVar(&xpr.DRCFile, "drc-report", "", "The file to write the desitn rule check report to")

	var defines RepeatedString
	flag.Var(&defines, "define", "list of (System)Verilog defines")

	var generics RepeatedString
	flag.Var(&generics, "generic", "a VHDL generic in KEY=VALUE format")
	flag.Parse()

	// Load a custom template if specified.
	var customTemplate *template.Template

	if customTemplateFileName != "" {
		f, err := os.Open(customTemplateFileName)
		if err != nil {
			log.Fatalf("while opening: %v: %v", customTemplateFileName, err)
		}
		b, err := io.ReadAll(f)
		if err != nil {
			log.Fatalf("while reading: %v: %v", customTemplateFileName, err)
		}
		s := string(b)
		customTemplate = template.Must(template.New("custom").Parse(s))
	}

	// Build the data model.
	var (
		pPaths []string
	)
	for i := 0; i < dirDepth; i++ {
		pPaths = append(pPaths, "..")
	}
	ppath := strings.Join(pPaths, "/")

	var verilogFiles, systemVerilogFiles, VHDLFiles, OtherFiles []FileLib

	for _, v := range libraryFiles.values {
		s := strings.Split(v, "=")
		if err := AppendTo(&systemVerilogFiles, &verilogFiles, &VHDLFiles,
			&OtherFiles, FileLib{Name: s[1], Library: s[0]}); err != nil {
			log.Fatalf("while classifying: %v: %v", v, err)
		}
	}

	// Sort the different program files into their own file type lists. Order
	// is significant.
	for _, v := range sources.values {
		if err := AppendTo(&systemVerilogFiles, &verilogFiles, &VHDLFiles,
			&OtherFiles, FileLib{Name: v}); err != nil {
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

	// Fill out the values that aren't directly available in flags.
	xpr.VerilogProperties = defines.values
	xpr.SystemVerilogFiles = systemVerilogFiles
	xpr.VerilogFiles = verilogFiles
	xpr.VHDLFiles = VHDLFiles
	xpr.OtherFiles = OtherFiles
	xpr.VerilogHeaders = headers.values
	xpr.VerilogIncludeDirs = vDirs
	xpr.XDCFiles = xdcFiles.values
	xpr.PWD = pwd
	xpr.VHDLGenerics = generics.values

	if xpr.OutXpr != "" {
		if err := WriteFile(xpr.OutXpr, xprTpl, &xpr); err != nil {
			log.Fatalf("while writing XPR file: %v: %v", xpr.OutXpr, err)
		}
	}
	if xpr.SynthFileName != "" {
		if err := WriteFile(xpr.SynthFileName, syntTpl, &xpr); err != nil {
			log.Fatalf("while writing synth file: %v: %v", xpr.SynthFileName, err)
		}
	}
	if xpr.PnrFileName != "" {
		if err := WriteFile(xpr.PnrFileName, pnrTpl, &xpr); err != nil {
			log.Fatalf("while writing PNR file: %v: %v", xpr.PnrFileName, err)
		}
	}
	if xpr.CustomFileName != "" {
		if err := WriteFile(xpr.CustomFileName, customTemplate, &xpr); err != nil {
			log.Fatalf("while writing file: %v: %v", xpr.CustomFileName, err)
		}
	}
}
