//go:build windows

package system

import "os/exec"

func Shutdown() error {
	return exec.Command("shutdown", "/s", "/t", "0", "/f").Run()
}
