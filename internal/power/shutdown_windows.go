//go:build windows

package power

import "os/exec"

func Shutdown() error {
	return exec.Command("shutdown.exe", "/s", "/t", "0").Start()
}
