package main

import (
	"bytes"
	"testing"
	"text/template"
)

func TestTemplates(t *testing.T) {
	xpr := &XPRBinding{
		Project: "TestProject",
		PWD:     "/tmp",
		OutXpr:  "out.xpr",
		Fileset: "sources_1",
		Top:     "top",
		VerilogProperties: []string{"DEF1", "DEF2"},
		SystemVerilogFiles: []FileLib{
			{Name: "sv1.sv", Library: "lib1"},
			{Name: "sv2.sv"},
		},
		VerilogFiles: []FileLib{
			{Name: "v1.v", Library: "lib2"},
			{Name: "v2.v"},
		},
		VerilogHeaders: []string{"h1.vh"},
		VHDLFiles: []FileLib{
			{Name: "vhdl1.vhd", Library: "lib3"},
		},
		VerilogIncludeDirs: []string{"inc1", "inc2"},
		XDCFiles:           []string{"con1.xdc"},
		OtherFiles: []FileLib{
			{Name: "other1.txt"},
		},
		Part: "xc7a200tfbg484-2",
	}

	tests := []struct {
		name string
		tpl  *template.Template
	}{
		{"syntTpl", syntTpl},
		{"xprTpl", xprTpl},
		{"pnrTpl", pnrTpl},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var buf bytes.Buffer
			if err := tt.tpl.Execute(&buf, xpr); err != nil {
				t.Errorf("failed to execute %s: %v", tt.name, err)
			}
			if buf.Len() == 0 {
				t.Errorf("%s produced empty output", tt.name)
			}
		})
	}
}
