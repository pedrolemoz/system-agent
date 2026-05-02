//go:build linux

package system

import "os/exec"

func Shutdown() error {
	if err := exec.Command("systemctl", "poweroff").Run(); err == nil {
		return nil
	}
	return exec.Command("shutdown", "-h", "now").Run()
}
