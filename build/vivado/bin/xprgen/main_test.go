package main

import (
	"testing"
)

func TestRepeatedString(t *testing.T) {
	var rs RepeatedString

	// Test Empty() on new instance
	if !rs.Empty() {
		t.Errorf("Empty() = false, want true for new RepeatedString")
	}

	// Test Set() and Empty()
	if err := rs.Set("value1"); err != nil {
		t.Errorf("Set(\"value1\") error: %v", err)
	}
	if rs.Empty() {
		t.Errorf("Empty() = true, want false after Set()")
	}

	// Test String() with one value
	if got, want := rs.String(), "value1"; got != want {
		t.Errorf("String() = %q, want %q", got, want)
	}

	// Test Set() with second value
	if err := rs.Set("value2"); err != nil {
		t.Errorf("Set(\"value2\") error: %v", err)
	}

	// Test String() with multiple values
	if got, want := rs.String(), "value1,value2"; got != want {
		t.Errorf("String() = %q, want %q", got, want)
	}

	// Test Set() with empty string
	if err := rs.Set(""); err != nil {
		t.Errorf("Set(\"\") error: %v", err)
	}
	if got, want := rs.String(), "value1,value2,"; got != want {
		t.Errorf("String() = %q, want %q", got, want)
	}
}
