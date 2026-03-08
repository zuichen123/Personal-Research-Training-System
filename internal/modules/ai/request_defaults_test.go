package ai

import "testing"

func TestNormalizeGenerateRequest(t *testing.T) {
	tests := []struct {
		name string
		in   GenerateRequest
		want GenerateRequest
	}{
		{
			name: "apply defaults",
			in:   GenerateRequest{},
			want: GenerateRequest{Count: 3, Difficulty: 2, Subject: "general"},
		},
		{
			name: "cap count and trim subject",
			in:   GenerateRequest{Count: 30, Difficulty: 4, Subject: "  math  "},
			want: GenerateRequest{Count: 20, Difficulty: 4, Subject: "  math  "},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := normalizeGenerateRequest(tc.in)
			if got.Count != tc.want.Count || got.Difficulty != tc.want.Difficulty || got.Subject != tc.want.Subject {
				t.Fatalf("normalizeGenerateRequest(%+v)=%+v, want %+v", tc.in, got, tc.want)
			}
		})
	}
}
