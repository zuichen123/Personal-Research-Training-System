package ai

import "math"

func roundOneDecimal(v float64) float64 {
	return math.Round(v*10) / 10
}
