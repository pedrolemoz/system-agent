//go:build linux

package metrics

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func collectGPU() *GPU {
	if g := nvidiaGPU(); g != nil {
		return g
	}
	return sysGPU()
}

func sysGPU() *GPU {
	vendors, _ := filepath.Glob("/sys/class/drm/card*/device/vendor")
	for _, vpath := range vendors {
		data, err := os.ReadFile(vpath)
		if err != nil {
			continue
		}
		vendor := strings.TrimSpace(string(data))
		// AMD=0x1002, Intel=0x8086
		if vendor != "0x1002" && vendor != "0x8086" {
			continue
		}
		dir := filepath.Dir(vpath)

		name := sysRead(filepath.Join(dir, "product_name"))
		if name == "" {
			name = "Unknown GPU"
		}

		usageStr := sysRead(filepath.Join(dir, "gpu_busy_percent"))
		usage, _ := strconv.ParseFloat(usageStr, 64)

		var tempPtr *float64
		hwmons, _ := filepath.Glob(filepath.Join(dir, "hwmon/hwmon*/temp1_input"))
		if len(hwmons) > 0 {
			if t, err := strconv.ParseFloat(sysRead(hwmons[0]), 64); err == nil && t > 0 {
				v := round1(t / 1000)
				tempPtr = &v
			}
		}

		totalStr := sysRead(filepath.Join(dir, "mem_info_vram_total"))
		usedStr := sysRead(filepath.Join(dir, "mem_info_vram_used"))
		total, _ := strconv.ParseUint(totalStr, 10, 64)
		used, _ := strconv.ParseUint(usedStr, 10, 64)
		totalMB := total / 1024 / 1024
		usedMB := used / 1024 / 1024
		freeMB := totalMB - usedMB

		return &GPU{
			Present:     true,
			Name:        name,
			UsagePct:    round1(usage),
			TempCelsius: tempPtr,
			VRAM:        VRAM{TotalMB: totalMB, InUseMB: usedMB, FreeMB: freeMB},
		}
	}
	return nil
}

func sysRead(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}
