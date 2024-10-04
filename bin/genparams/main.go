package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"text/template"
)

type KVList struct {
	values []string
}

var _ flag.Value = (*KVList)(nil)

func (self *KVList) Set(v string) error {
	sp := strings.Split(v, " ")
	self.values = append(self.values, sp[0])
	return nil
}

func (self *KVList) String() string {
	var out []string
	for _, e := range self.values {
		out = append(out, e)
	}
	return strings.Join(out, ";")
}

func (self *KVList) Iter() []string {
	return self.values
}

var (
	xdcTmpl = template.Must(template.New("x").Parse(`
# Generated file do not edit.

{{$synth := .Synth}}
{{range .Values}}
    set_property generic { {{.}} } [ get_filesets {{$synth}} ]
{{end}}

# End.
`))
)

type Bindings struct {
	Values []string
	Synth  string // remove this.
}

func main() {
	var b Bindings
	var (
		generics KVList
	)
	flag.Var(&generics, "generic", "Adds a new generic value")
	flag.StringVar(&b.Synth, "synth-name", "synth_1", "The name of the synthesis files")
	flag.Parse()

	b.Values = generics.Iter()

	if err := xdcTmpl.Execute(os.Stdout, b); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v", err)
		os.Exit(1)
	}
}
