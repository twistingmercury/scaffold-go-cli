# How to use this template

## Purpose

The purpose of this template is to create an executable binary that is run
directly on the machine from the terminal. It does not create a final image.

## Prerequisites

- Go 1.27.3 or later, for `make local`, `make test`, and `make install`
- Docker, for `make build`
- `goimports`, `golangci-lint`, `govulncheck`, and `gosec`, for `make analyze`

## Start fresh

If you cloned this template, delete its git history before anything else:

```sh
rm -rf .git
```

## Update values

The following values will need to be updated for your project:

| File                            | Value to be updated                          | Why?                                                                                              |
| ------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| src/go.mod                      | `module go/basic/scaffold`                   | This is the module name for the project. The Makefile and build.sh read it from here              |
| src/cmd/main.go                 | `"go/basic/scaffold/internal/config"` import | This import path needs to match the new module name, or be deleted if config is not used          |
| build/build.sh                  | `APP_NAME`                                   | Sets the name for the compiled binaries from `make build`                                         |
| Makefile                        | `APP_NAME`                                   | Sets the name for the binary from `make local` and `make install`                                 |
| src/internal/version/version.go | `appName`                                    | The name printed by `version.Print()`                                                             |
| src/internal/config/config.go   | `EnvPrefix`, `EnvConfigFile`                 | The prefix for the app's environment variables, e.g. `SCAFFOLD_`                                  |
| LICENSE                         | `YOUR_NAME`                                  | The copyright holder. The default license is MIT, so swap the whole text if that doesn't suit you |
| README.md                       | Title, version, and contents                 | The README still describes the template, not your app                                             |
| build/Dockerfile                | The pinned `golang-tooling` image            | Make sure it's the latest image published at `ghcr.io/twistingmercury/golang-tooling`             |

When you're done, this should print nothing:

```sh
grep -rniE 'scaffold|YOUR_NAME' --exclude-dir=.git --exclude-dir=.bin --exclude=HOWTO.md .
```

## Next steps

After updating the values, you will need to do the following:

1. Run `git init`. For example, I typically run: `git init --initial-branch develop`.
2. Run `make local` - this should place a binary under this path: `[project root]/.bin/local/`
3. Run `make build` - this should place a binary under these paths:
   - `[project root]/.bin/amd64/darwin/`
   - `[project root]/.bin/amd64/linux/`
   - `[project root]/.bin/amd64/windows/`
   - `[project root]/.bin/arm64/darwin/`
   - `[project root]/.bin/arm64/linux/`
4. Add and commit the basic project. For example, I typically run: `git add -A && git commit -s -m "initial project setup"`.
   `-s` here adds a `Signed-off-by` line to the commit message.
5. Tag the initial commit. For example, I typically run: `git tag -a v0.0.1 -s -m "initial project setup"`.
   `-s` here means something different: it GPG-signs the tag, which only works if you have a signing key set up. Drop it if you don't.

Once all this is done, you can ignore this file and delete it if you wish.
