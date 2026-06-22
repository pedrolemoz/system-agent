//go:build linux

package power

import "os/exec"

func Shutdown() error {
	return exec.Command("systemctl", "poweroff").Start()
}
