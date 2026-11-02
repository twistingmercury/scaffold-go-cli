package version

import (
	"fmt"
	"runtime"
)

var (
	version   = "dev"     // set via -ldflags: -X <your go module>/internal/version.version=<value>
	buildDate = "unknown" // set via -ldflags: -X <your go module>/internal/version.buildDate=<value>
	gitCommit = "unknown" // set via -ldflags: -X <your go module>/internal/version.gitCommit=<value>
)

const appName = "scaffold"

// Version returns the app's version set at build time.
func Version() string {
	return version
}

func Print() {
	fmt.Printf("%s version: %s\ndate: %s\ncommit: %s\nos: %s/%s\n", appName, version, buildDate, gitCommit, runtime.GOOS, runtime.GOARCH)
}
