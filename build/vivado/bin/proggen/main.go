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
	GotoptFile    string
	BitFile       string
}

func printEnv() {
	for _, e := range os.Environ() {
		log.Printf("env: %v", e)
	}
}

func run(args Args) error {
	printEnv()

	if args.BitFile == "" {
		return fmt.Errorf("param --bitfile is required.")
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

func main() {

	var args Args
	flag.StringVar(&args.Outfile, "outfile", "", "The output file to generate")
	flag.StringVar(&args.TemplateFile, "template", "", "The template file to use for generation")
	flag.StringVar(&args.RunDockerFile, "run-docker", "", "The script for running docker")
	flag.StringVar(&args.GotoptFile, "gotopt2", "", "the gotopt2 binary to use")
	flag.StringVar(&args.BitFile, "bitfile", "", "")

	flag.Parse()

	if err := run(args); err != nil {
		log.Printf("ERROR:\n\twhile running: %v:\n\t%v", os.Args[0], err)
		os.Exit(1)
	}

}
