package main

import (
	"testing"
)

func TestKVListSet(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{
			name:    "valid",
			input:   "KEY=VALUE",
			wantErr: false,
		},
		{
			name:    "invalid - no equals",
			input:   "KEY",
			wantErr: true,
		},
		{
			name:    "invalid - empty",
			input:   "",
			wantErr: true,
		},
		{
			name:    "valid with space",
			input:   "KEY=VALUE something else",
			wantErr: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvl := &KVList{}
			if err := kvl.Set(tt.input); (err != nil) != tt.wantErr {
				t.Errorf("KVList.Set() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestKVListString(t *testing.T) {
	tests := []struct {
		name   string
		values []KV
		want   string
	}{
		{
			name:   "empty",
			values: nil,
			want:   "",
		},
		{
			name: "single",
			values: []KV{
				{Key: "K1", Value: "V1"},
			},
			want: "K1=V1",
		},
		{
			name: "multiple",
			values: []KV{
				{Key: "K1", Value: "V1"},
				{Key: "K2", Value: "V2"},
				{Key: "K3", Value: "V3"},
			},
			want: "K1=V1;K2=V2;K3=V3",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvl := &KVList{values: tt.values}
			if got := kvl.String(); got != tt.want {
				t.Errorf("KVList.String() = %v, want %v", got, tt.want)
			}
		})
	}
}

func BenchmarkKVListString(b *testing.B) {
	kvl := &KVList{
		values: []KV{
			{Key: "Key1", Value: "Value1"},
			{Key: "Key2", Value: "Value2"},
			{Key: "Key3", Value: "Value3"},
			{Key: "Key4", Value: "Value4"},
			{Key: "Key5", Value: "Value5"},
		},
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = kvl.String()
	}
}
