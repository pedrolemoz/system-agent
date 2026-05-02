//go:build linux

package metrics

import (
	"strings"

	"github.com/shirou/gopsutil/v3/host"
)

func cpuTemp() *float64 {
	temps, err := host.SensorsTemperatures()
	if err != nil || len(temps) == 0 {
		return nil
	}
	keywords := []string{"cpu", "core", "tdie", "tctl", "package", "k10temp", "coretemp"}
	for _, t := range temps {
		key := strings.ToLower(t.SensorKey)
		for _, kw := range keywords {
			if strings.Contains(key, kw) && t.Temperature > 0 && t.Temperature < 150 {
				v := round1(t.Temperature)
				return &v
			}
		}
	}
	for _, t := range temps {
		if t.Temperature > 20 && t.Temperature < 120 {
			v := round1(t.Temperature)
			return &v
		}
	}
	return nil
}
