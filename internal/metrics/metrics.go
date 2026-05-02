package metrics

import (
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/mem"
)

type RAM struct {
	TotalMB uint64 `json:"total_in_mb"`
	InUseMB uint64 `json:"in_use_in_mb"`
	FreeMB  uint64 `json:"free_in_mb"`
}

type CPU struct {
	Name        string   `json:"name"`
	Cores       int      `json:"cores"`
	Threads     int      `json:"threads"`
	UsagePct    float64  `json:"usage_percentage"`
	TempCelsius *float64 `json:"temperature_in_celsius"`
}

type VRAM struct {
	TotalMB uint64 `json:"total_in_mb"`
	InUseMB uint64 `json:"in_use_in_mb"`
	FreeMB  uint64 `json:"free_in_mb"`
}

type GPU struct {
	Present     bool     `json:"present"`
	Name        string   `json:"name"`
	UsagePct    float64  `json:"usage_percentage"`
	TempCelsius *float64 `json:"temperature_in_celsius"`
	VRAM        VRAM     `json:"vram"`
}

type Metrics struct {
	RAM RAM  `json:"ram"`
	CPU CPU  `json:"cpu"`
	GPU *GPU `json:"gpu"`
}

func collect() (*Metrics, error) {
	vm, err := mem.VirtualMemory()
	if err != nil {
		return nil, err
	}
	ram := RAM{
		TotalMB: vm.Total / 1024 / 1024,
		InUseMB: vm.Used / 1024 / 1024,
		FreeMB:  vm.Available / 1024 / 1024,
	}

	infos, err := cpu.Info()
	if err != nil || len(infos) == 0 {
		return nil, err
	}
	physCores, _ := cpu.Counts(false)
	logThreads, _ := cpu.Counts(true)
	pcts, _ := cpu.Percent(0, false)
	usage := 0.0
	if len(pcts) > 0 {
		usage = round1(pcts[0])
	}

	c := CPU{
		Name:        infos[0].ModelName,
		Cores:       physCores,
		Threads:     logThreads,
		UsagePct:    usage,
		TempCelsius: cpuTemp(),
	}

	return &Metrics{RAM: ram, CPU: c, GPU: collectGPU()}, nil
}


func round1(f float64) float64 {
	return float64(int(f*10+0.5)) / 10
}
