package main

import (
	"reflect"
	"testing"
)

func TestAppendTo(t *testing.T) {
	tests := []struct {
		name               string
		fl                 FileLib
		initialSV          []FileLib
		initialV           []FileLib
		initialVHDL        []FileLib
		initialOther       []FileLib
		wantSV             []FileLib
		wantV              []FileLib
		wantVHDL           []FileLib
		wantOther          []FileLib
		wantErr            bool
	}{
		{
			name: "SystemVerilog file",
			fl:   FileLib{Name: "test.sv"},
			wantSV: []FileLib{{Name: "test.sv"}},
		},
		{
			name: "Verilog file",
			fl:   FileLib{Name: "test.v"},
			wantV: []FileLib{{Name: "test.v"}},
		},
		{
			name: "VHDL file 1",
			fl:   FileLib{Name: "test.vhd"},
			wantVHDL: []FileLib{{Name: "test.vhd"}},
		},
		{
			name: "VHDL file 2",
			fl:   FileLib{Name: "test.vhdl"},
			wantVHDL: []FileLib{{Name: "test.vhdl"}},
		},
		{
			name: "Other file",
			fl:   FileLib{Name: "test.txt"},
			wantOther: []FileLib{{Name: "test.txt"}},
		},
		{
			name:    "Empty filename",
			fl:      FileLib{Name: ""},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sv := tt.initialSV
			v := tt.initialV
			vhdl := tt.initialVHDL
			other := tt.initialOther

			err := AppendTo(&sv, &v, &vhdl, &other, tt.fl)
			if (err != nil) != tt.wantErr {
				t.Errorf("AppendTo() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !reflect.DeepEqual(sv, tt.wantSV) {
				t.Errorf("AppendTo() sv = %v, want %v", sv, tt.wantSV)
			}
			if !reflect.DeepEqual(v, tt.wantV) {
				t.Errorf("AppendTo() v = %v, want %v", v, tt.wantV)
			}
			if !reflect.DeepEqual(vhdl, tt.wantVHDL) {
				t.Errorf("AppendTo() vhdl = %v, want %v", vhdl, tt.wantVHDL)
			}
			if !reflect.DeepEqual(other, tt.wantOther) {
				t.Errorf("AppendTo() other = %v, want %v", other, tt.wantOther)
			}
		})
	}
}
