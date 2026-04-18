package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"text/template"
)

type KV struct {
	Key, Value string
}

type KVList struct {
	values []KV
}

var _ flag.Value = (*KVList)(nil)

func (self *KVList) Set(v string) error {
	sp := strings.Split(v, " ")[0]
	kv := strings.Split(sp, "=")
	if len(kv) < 2 {
		return fmt.Errorf("invalid format: expected KEY=VALUE, got %q", v)
	}
	k, v := kv[0], kv[1]
	self.values = append(self.values, KV{Key: k, Value: v})
	return nil
}

func (self *KVList) String() string {
	var out strings.Builder
	for i, e := range self.values {
		if i > 0 {
			out.WriteByte(';')
		}
		out.WriteString(e.Key)
		out.WriteByte('=')
		out.WriteString(e.Value)
	}
	return out.String()
}

func (self *KVList) Iter() []KV {
	return self.values
}

var (
	xdcTmpl = template.Must(template.New("x").Parse(`
{{- $vt := .VerilogTop -}}
# Generated file do not edit.
# VerilogTop: {{$vt}}

{{range .Params}}
    set_property PARAMETER.{{ .Key}} {{.Value}} [get_cells {{$vt}}]
{{end}}

# End.
`))
)

type Bindings struct {
	// Params are for Verilog, Values are for VHDL - apparently.
	Values, Params      []KV
	VerilogTop, VHDLTop string
}

func run(args []string, stdout, stderr io.Writer) int {
	var b Bindings
	var (
		generics, params KVList
	)

	fs := flag.NewFlagSet("genparams", flag.ContinueOnError)
	fs.SetOutput(stderr)

	fs.Var(&generics, "generic", "Adds a new generic value (for VHDL)")
	fs.Var(&params, "param", "Adds a new param value (for Verilog)")
	fs.StringVar(&b.VerilogTop, "verilog-top", "", "Adds a new param value (for Verilog)")
	fs.StringVar(&b.VHDLTop, "vhdl-top", "", "Adds a new top level value (for VHDL)")

	if err := fs.Parse(args); err != nil {
		return 1
	}

	if b.VHDLTop != "" {
		fmt.Fprintf(stderr, "--vhdl-top flag is unimplemented\n")
		return 1
	}

	b.Values = generics.Iter()
	b.Params = params.Iter()

	if err := xdcTmpl.Execute(stdout, b); err != nil {
		fmt.Fprintf(stderr, "error: %v\n", err)
		return 1
	}

	return 0
}

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}
