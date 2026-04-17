package main

import (
	"bytes"
	"log"
	"strings"
	"testing"
)

func TestRunDoesNotLogEnv(t *testing.T) {
	var buf bytes.Buffer
	oldOutput := log.Writer()
	log.SetOutput(&buf)
	defer log.SetOutput(oldOutput)

	// Call run with minimal arguments. It will return an error because
	// required fields are missing, but it should NOT have logged the environment.
	_ = run(Args{})

	output := buf.String()
	if strings.Contains(output, "env: ") {
		t.Errorf("Found sensitive environment data in logs: %q", output)
	}
}
