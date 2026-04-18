package main

import (
	"io"
	"log"
	"testing"
)

func BenchmarkPrintEnv_Verbose(b *testing.B) {
	log.SetOutput(io.Discard)
	for i := 0; i < b.N; i++ {
		printEnv(true)
	}
}

func BenchmarkPrintEnv_NonVerbose(b *testing.B) {
	log.SetOutput(io.Discard)
	for i := 0; i < b.N; i++ {
		printEnv(false)
	}
}
