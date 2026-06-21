package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"text/template"
)

type Args struct {
	Outfile      string
	TemplateFile string

	RunDockerFile string
	GotoptFile    string
	BitFile       string

	// Flash (cfgmem) programming mode. When McsFile is set, the generator
	// emits a script that programs the device's non-volatile configuration
	// flash with the given flash image instead of the FPGA SRAM.
	McsFile        string
	FlashPart      string
	FlashInterface string

	ProgRunnerArgs   string
	ProgRunnerBinary string

	VivadoVersion string
}

func printEnv() {
	for _, e := range os.Environ() {
		log.Printf("env: %v", e)
	}
}

func run(args Args) error {
	printEnv()

	if args.BitFile == "" && args.McsFile == "" {
		return fmt.Errorf("one of --bitfile or --mcs-file is required.")
	}
	if args.RunDockerFile == "" {
		return fmt.Errorf("param --run-docker is required.")
	}
	if args.GotoptFile == "" {
		return fmt.Errorf("param --gotopt2 is required")
	}
	if args.Outfile == "" {
		return fmt.Errorf("param --outfile is required")
	}
	if args.TemplateFile == "" {
		return fmt.Errorf("param --template is required")
	}
	if args.VivadoVersion == "" {
		return fmt.Errorf("param --vivado-version is required")
	}

	tpl, err := template.ParseFiles(args.TemplateFile)
	if err != nil {
		return fmt.Errorf("could not open or parse template file: %v:\n\t\t%w", args.TemplateFile, err)
	}

	of, err := os.Create(args.Outfile)
	if err != nil {
		return fmt.Errorf("could not create outfile: %v:\n\t\t%w", args.Outfile, err)
	}
	defer of.Close()

	if err := tpl.ExecuteTemplate(of, filepath.Base(args.TemplateFile), &args); err != nil {
		return fmt.Errorf("could not write outfile:\n\t%v:\n\t\t%w", args.Outfile, err)
	}

	return nil
}

func runCLI(cmdArgs []string) error {
	var args Args
	fs := flag.NewFlagSet("proggen", flag.ContinueOnError)
	fs.StringVar(&args.Outfile, "outfile", "", "The output file to generate")
	fs.StringVar(&args.TemplateFile, "template", "", "The template file to use for generation")
	fs.StringVar(&args.RunDockerFile, "run-docker", "", "The script for running docker")
	fs.StringVar(&args.GotoptFile, "gotopt2", "", "the gotopt2 binary to use")
	fs.StringVar(&args.BitFile, "bitfile", "", "")
	fs.StringVar(&args.McsFile, "mcs-file", "", "The flash image (.mcs/.bin) to program into configuration flash")
	fs.StringVar(&args.FlashPart, "flash-part", "", "The Vivado cfgmem part name of the target flash device")
	fs.StringVar(&args.FlashInterface, "flash-interface", "", "The flash programming interface, e.g. SPIx4")
	fs.StringVar(&args.ProgRunnerArgs, "prog-runner-args", "", "the arguments to invoke the runner with")
	fs.StringVar(&args.ProgRunnerBinary, "prog-runner-binary", "", "The program runner binary")
	fs.StringVar(&args.VivadoVersion, "vivado-version", "", "The Vivado version to use")

	if err := fs.Parse(cmdArgs); err != nil {
		return err
	}

	return run(args)
}

func main() {
	if err := runCLI(os.Args[1:]); err != nil {
		log.Printf("ERROR:\n\twhile running: %v:\n\t%v", os.Args[0], err)
		os.Exit(1)
	}
}
