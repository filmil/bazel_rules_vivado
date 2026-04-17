package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRun(t *testing.T) {
	tempDir := t.TempDir()

	validTemplatePath := filepath.Join(tempDir, "main_script.tpl.sh")
	validTemplateContent := `{{define "main_script.tpl.sh"}}Success{{end}}`
	if err := os.WriteFile(validTemplatePath, []byte(validTemplateContent), 0644); err != nil {
		t.Fatalf("failed to write mock template: %v", err)
	}

	validArgs := Args{
		Outfile:       filepath.Join(tempDir, "output.sh"),
		TemplateFile:  validTemplatePath,
		RunDockerFile: "run_docker.sh",
		GotoptFile:    "gotopt2",
		BitFile:       "design.bit",
	}

	tests := []struct {
		name      string
		args      Args
		wantError string
	}{
		{
			name:      "missing bitfile",
			args:      Args{RunDockerFile: "a", GotoptFile: "b", Outfile: "c", TemplateFile: "d"},
			wantError: "param --bitfile is required.",
		},
		{
			name:      "missing run-docker",
			args:      Args{BitFile: "a", GotoptFile: "b", Outfile: "c", TemplateFile: "d"},
			wantError: "param --run-docker is required.",
		},
		{
			name:      "missing gotopt2",
			args:      Args{BitFile: "a", RunDockerFile: "b", Outfile: "c", TemplateFile: "d"},
			wantError: "param --gotopt2 is required",
		},
		{
			name:      "missing outfile",
			args:      Args{BitFile: "a", RunDockerFile: "b", GotoptFile: "c", TemplateFile: "d"},
			wantError: "param --outfile is required",
		},
		{
			name:      "missing template",
			args:      Args{BitFile: "a", RunDockerFile: "b", GotoptFile: "c", Outfile: "d"},
			wantError: "param --template is required",
		},
		{
			name: "invalid template path",
			args: Args{
				BitFile:       "a",
				RunDockerFile: "b",
				GotoptFile:    "c",
				Outfile:       "d",
				TemplateFile:  filepath.Join(tempDir, "nonexistent.tpl"),
			},
			wantError: "could not open or parse template file",
		},
		{
			name: "success",
			args: validArgs,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			err := run(tc.args)

			if tc.wantError != "" {
				if err == nil {
					t.Fatalf("expected error containing %q, got nil", tc.wantError)
				}
				if !strings.Contains(err.Error(), tc.wantError) {
					t.Errorf("expected error containing %q, got %v", tc.wantError, err)
				}
			} else {
				if err != nil {
					t.Fatalf("expected no error, got %v", err)
				}
				// Verify output for successful execution
				if tc.name == "success" {
					content, err := os.ReadFile(tc.args.Outfile)
					if err != nil {
						t.Fatalf("failed to read outfile: %v", err)
					}
					if string(content) != "Success" {
						t.Errorf("expected outfile to contain 'Success', got %q", string(content))
					}
				}
			}
		})
	}
}
