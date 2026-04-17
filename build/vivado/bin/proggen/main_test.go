package main

import (
	"os"
	"testing"
)

func TestRunRequiresArgs(t *testing.T) {
	args := Args{}
	err := run(args)
	if err == nil {
		t.Errorf("expected error when running with empty args, got nil")
	}
}

func TestRunSuccess(t *testing.T) {
	// Create dummy files for template and output
	tplFile := "test.tpl"
	outFile := "test.out"
	defer os.Remove(tplFile)
	defer os.Remove(outFile)

	err := os.WriteFile(tplFile, []byte(`{{define "main_script.tpl.sh"}}test template{{end}}`), 0644)
	if err != nil {
		t.Fatalf("failed to create test template: %v", err)
	}

	args := Args{
		BitFile:       "bit",
		RunDockerFile: "docker",
		GotoptFile:    "gotopt",
		Outfile:       outFile,
		TemplateFile:  tplFile,
	}

	err = run(args)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}

	if _, err := os.Stat(outFile); os.IsNotExist(err) {
		t.Errorf("expected outfile to be created")
	}
}
