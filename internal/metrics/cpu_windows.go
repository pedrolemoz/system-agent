//go:build windows

package metrics

// cpuTemp returns nil on Windows.
// Standard Windows APIs (WMI MSAcpi_ThermalZoneTemperature, Thermal Zone perf counters)
// expose ACPI ambient/chassis zones, not CPU core temperature.
// Accurate Intel core temps require third-party drivers (LibreHardwareMonitor, HWiNFO64).
func cpuTemp() *float64 {
	return nil
}
