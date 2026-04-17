package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRun(t *testing.T) {
	tmpDir := t.TempDir()

	templatePath := filepath.Join(tmpDir, "main_script.tpl.sh")
	err := os.WriteFile(templatePath, []byte("BitFile: {{.BitFile}}"), 0644)
	if err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		name    string
		args    Args
		wantErr bool
	}{
		{
			name: "missing BitFile",
			args: Args{
				RunDockerFile: "docker.sh",
				GotoptFile:    "gotopt2",
				Outfile:       filepath.Join(tmpDir, "out1.sh"),
				TemplateFile:  templatePath,
			},
			wantErr: true,
		},
		{
			name: "missing RunDockerFile",
			args: Args{
				BitFile:      "test.bit",
				GotoptFile:   "gotopt2",
				Outfile:      filepath.Join(tmpDir, "out2.sh"),
				TemplateFile: templatePath,
			},
			wantErr: true,
		},
		{
			name: "missing GotoptFile",
			args: Args{
				BitFile:       "test.bit",
				RunDockerFile: "docker.sh",
				Outfile:       filepath.Join(tmpDir, "out3.sh"),
				TemplateFile:  templatePath,
			},
			wantErr: true,
		},
		{
			name: "missing Outfile",
			args: Args{
				BitFile:       "test.bit",
				RunDockerFile: "docker.sh",
				GotoptFile:    "gotopt2",
				TemplateFile:  templatePath,
			},
			wantErr: true,
		},
		{
			name: "missing TemplateFile",
			args: Args{
				BitFile:       "test.bit",
				RunDockerFile: "docker.sh",
				GotoptFile:    "gotopt2",
				Outfile:       filepath.Join(tmpDir, "out4.sh"),
			},
			wantErr: true,
		},
		{
			name: "success",
			args: Args{
				BitFile:       "test.bit",
				RunDockerFile: "docker.sh",
				GotoptFile:    "gotopt2",
				Outfile:       filepath.Join(tmpDir, "out5.sh"),
				TemplateFile:  templatePath,
			},
			wantErr: false,
		},
		{
			name: "template does not exist",
			args: Args{
				BitFile:       "test.bit",
				RunDockerFile: "docker.sh",
				GotoptFile:    "gotopt2",
				Outfile:       filepath.Join(tmpDir, "out6.sh"),
				TemplateFile:  filepath.Join(tmpDir, "nonexistent.tpl"),
			},
			wantErr: true,
		},
		{
			name: "cannot create outfile",
			args: Args{
				BitFile:       "test.bit",
				RunDockerFile: "docker.sh",
				GotoptFile:    "gotopt2",
				Outfile:       filepath.Join(tmpDir, "nonexistent_dir/out.sh"),
				TemplateFile:  templatePath,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := run(tt.args)
			if (err != nil) != tt.wantErr {
				t.Errorf("run() error = %v, wantErr %v", err, tt.wantErr)
			}

			if !tt.wantErr {
				if _, err := os.Stat(tt.args.Outfile); os.IsNotExist(err) {
					t.Errorf("run() did not create outfile %v", tt.args.Outfile)
				}
			}
		})
	}
}
