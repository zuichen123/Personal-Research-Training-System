package ai

import "testing"

func TestRoundOneDecimal(t *testing.T) {
	if got := roundOneDecimal(88.88); got != 88.9 {
		t.Fatalf("roundOneDecimal(88.88)=%v, want 88.9", got)
	}
}
