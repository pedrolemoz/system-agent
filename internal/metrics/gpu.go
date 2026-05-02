package metrics

import (
	"os/exec"
	"strconv"
	"strings"
)

// nvidiaGPU tries nvidia-smi. Works on both Windows and Linux.
func nvidiaGPU() *GPU {
	out, err := exec.Command(
		"nvidia-smi",
		"--query-gpu=name,utilization.gpu,temperature.gpu,memory.total,memory.used,memory.free",
		"--format=csv,noheader,nounits",
	).Output()
	if err != nil {
		return nil
	}
	line := strings.TrimSpace(string(out))
	if i := strings.Index(line, "\n"); i >= 0 {
		line = line[:i]
	}
	parts := strings.Split(line, ", ")
	if len(parts) < 6 {
		return nil
	}
	name := strings.TrimSpace(parts[0])
	usage, _ := strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
	temp, _ := strconv.ParseFloat(strings.TrimSpace(parts[2]), 64)
	totalMB, _ := strconv.ParseUint(strings.TrimSpace(parts[3]), 10, 64)
	usedMB, _ := strconv.ParseUint(strings.TrimSpace(parts[4]), 10, 64)
	freeMB, _ := strconv.ParseUint(strings.TrimSpace(parts[5]), 10, 64)

	var tempPtr *float64
	if temp > 0 {
		v := round1(temp)
		tempPtr = &v
	}
	return &GPU{
		Present:     true,
		Name:        name,
		UsagePct:    round1(usage),
		TempCelsius: tempPtr,
		VRAM:        VRAM{TotalMB: totalMB, InUseMB: usedMB, FreeMB: freeMB},
	}
}
