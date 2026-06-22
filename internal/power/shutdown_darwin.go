//go:build darwin

package power

import "os/exec"

func Shutdown() error {
	return exec.Command("/sbin/shutdown", "-h", "now").Start()
}
