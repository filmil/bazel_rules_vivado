package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"text/template"
)

type Args struct {
	Outfile      string
	TemplateFile string

	RunDockerFile string
	// The runfiles (rlocation) path of the runner script that executes the
	// Vivado command: docker_run in docker mode, host_run in host mode.
	RunnerRlocation string
	GotoptFile      string
	LtxFile         string

	VivadoVersion string
	// The Vivado install path (in the container in docker mode; on the host
	// filesystem in host mode).
	VivadoPath string
	// The Vivado Docker image (docker mode only; ignored by host_run).
	Container string
	// The Vivado execution mode: "docker" (default) or "host".
	Mode string
	// The directory where generated files are visible to Vivado, computed
	// from Mode: /work inside the container, ${PWD} on the host.
	WorkDir string
}

func printEnv() {
	for _, e := range os.Environ() {
		log.Printf("env: %v", e)
	}
}

func run(args Args) error {
	printEnv()

	if args.LtxFile == "" {
		return fmt.Errorf("param --ltxfile is required.")
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
	// Fallbacks preserve the pre-toolchain behavior of the templates.
	if args.VivadoPath == "" {
		args.VivadoPath = fmt.Sprintf("/opt/Xilinx/%s/Vivado", args.VivadoVersion)
	}
	if args.Container == "" {
		args.Container = fmt.Sprintf("xilinx-vivado:%s", args.VivadoVersion)
	}
	if args.Mode == "" {
		args.Mode = "docker"
	}
	// In docker mode ${PWD} is bind-mounted at /work in the container; in
	// host mode the current directory is used directly. The value is a
	// literal shell expression expanded when the generated script runs.
	args.WorkDir = "/work"
	if args.Mode == "host" {
		args.WorkDir = "${PWD}"
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

	if err := tpl.ExecuteTemplate(of, "main_script.tpl.sh", &args); err != nil {
		return fmt.Errorf("could not write outfile:\n\t%v:\n\t\t%w", args.Outfile, err)
	}

	return nil
}

func runCLI(cmdArgs []string) error {
	var args Args
	fs := flag.NewFlagSet("ilagen", flag.ContinueOnError)
	fs.StringVar(&args.Outfile, "outfile", "", "The output file to generate")
	fs.StringVar(&args.TemplateFile, "template", "", "The template file to use for generation")
	fs.StringVar(&args.RunDockerFile, "run-docker", "", "The script for running docker")
	fs.StringVar(&args.RunnerRlocation, "runner-rlocation", "", "The rlocation path of the runner script (docker_run or host_run)")
	fs.StringVar(&args.GotoptFile, "gotopt2", "", "the gotopt2 binary to use")
	fs.StringVar(&args.LtxFile, "ltxfile", "", "The probes .ltx file")
	fs.StringVar(&args.VivadoVersion, "vivado-version", "", "The Vivado version to use")
	fs.StringVar(&args.VivadoPath, "vivado-path", "", "The Vivado install path (defaults to /opt/Xilinx/<version>/Vivado)")
	fs.StringVar(&args.Container, "container", "", "The Vivado Docker image (defaults to xilinx-vivado:<version>)")
	fs.StringVar(&args.Mode, "vivado-mode", "", "The Vivado execution mode: docker (default) or host")

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
