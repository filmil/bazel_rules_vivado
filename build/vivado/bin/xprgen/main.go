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

	var (
		sources, headers, includeDirs, defines      RepeatedString
		projectName, filesetName, topName           string
		dirDepth                                    int
		xprFileName, synthFileName, pnrFileName     string
		xdcFiles                                    RepeatedString
		part                                        string
		libraryFiles                                RepeatedString
		VHDLStandard                                string
		customFileName                              string
		customTemplateFileName                      string
		loadDcpName, saveDcpName                    string
		bitstreamName                               string
		timingSummaryName, utilizationName, drcName string
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
	flag.StringVar(&VHDLStandard, "vhdl-standard", "2008", "The VHDL language standard to use")

	flag.StringVar(&customFileName, "custom-filename", "", "Custom file to generate")
	flag.StringVar(&customTemplateFileName, "custom-template", "", "Custom file template")
	flag.StringVar(&loadDcpName, "load-dcp", "", "Input snapshot file")
	flag.StringVar(&saveDcpName, "save-dcp", "", "Output snapshot file")
	flag.StringVar(&bitstreamName, "bitstream", "", "Output bitstream file")
	flag.StringVar(&timingSummaryName, "timing-report", "", "")
	flag.StringVar(&utilizationName, "utilization-report", "", "")
	flag.StringVar(&drcName, "drc-report", "", "")
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

	var (
		verilogFiles       []FileLib
		systemVerilogFiles []FileLib
		VHDLFiles          []FileLib
		OtherFiles         []FileLib
	)

	for _, v := range libraryFiles.values {
		s := strings.Split(v, "=")
		if err := AppendTo(&systemVerilogFiles, &verilogFiles, &VHDLFiles, &OtherFiles, FileLib{Name: s[1], Library: s[0]}); err != nil {
			log.Fatalf("while classifying: %v: %v", v, err)
		}
	}

	// Sort the different program files into their own file type lists. Order
	// is significant.
	for _, v := range sources.values {
		if err := AppendTo(&systemVerilogFiles, &verilogFiles, &VHDLFiles, &OtherFiles, FileLib{Name: v}); err != nil {
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
		OtherFiles:         OtherFiles,
		VerilogHeaders:     headers.values,
		VerilogIncludeDirs: vDirs,
		XDCFiles:           xdcFiles.values,
		PWD:                pwd,
		OutXpr:             xprFileName,
		Part:               part,
		VHDLStandard:       VHDLStandard,
		LoadDcpFile:        loadDcpName,
		SaveDcpFile:        saveDcpName,
		BitstreamName:      bitstreamName,
		TimingSummaryFile:  timingSummaryName,
		UtilizationFile:    utilizationName,
		DRCFile:            drcName,
	}

	if xprFileName != "" {
		if err := WriteFile(xprFileName, xprTpl, &xpr); err != nil {
			log.Fatalf("while writing XPR file: %v: %v", xprFileName, err)
		}
	}
	if synthFileName != "" {
		if err := WriteFile(synthFileName, syntTpl, &xpr); err != nil {
			log.Fatalf("while writing synth file: %v: %v", synthFileName, err)
		}
	}
	if pnrFileName != "" {
		if err := WriteFile(pnrFileName, pnrTpl, &xpr); err != nil {
			log.Fatalf("while writing PNR file: %v: %v", pnrFileName, err)
		}
	}
	if customFileName != "" {
		if err := WriteFile(customFileName, customTemplate, &xpr); err != nil {
			log.Fatalf("while writing file: %v: %v", customFileName, err)
		}
	}
}
