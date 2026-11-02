# Go CLI App Template

> **Maturity Level**: Emerging - the template works end to end, but its layout and setup script may still change
> **Version**: v0.1.0
>
> - **Emerging**: Prototype, not production-ready, expect breaking changes
> - **Basic**: Production-ready but actively evolving, expect minor version changes
> - **Mature**: Stable, battle-tested, changes are rare

---

A template for Go command-line apps that get installed and run directly on a
machine, not hosted in a container. One script turns it into a working
project with a Docker-first build, cross-platform binaries, static analysis,
unit tests, black-box tests, and GitHub Actions CI.

## Table of Contents

- [Usage](#usage)
- [How it works](#how-it-works)
- [Key Considerations](#key-considerations)
- [Development Considerations](#development-considerations)
- [Versioning](#versioning)

## Usage

You need Go 1.27.3 or later, `make`, and a running Docker daemon.

From the root of a fresh copy of this template, run `scaffold_project.sh` with
your project's values:

```sh
GO_MODULE=github.com/you/myapp \
APP_NAME=myapp \
YOUR_NAME="Jane Doe" \
DELETE_GIT_DIR=1 \
GIT_INIT_DEVELOP=1 \
./scaffold_project.sh
```

| Variable           | Required | Value                                                                                   | Default                                    |
| ------------------ | -------- | --------------------------------------------------------------------------------------- | ------------------------------------------ |
| `GO_MODULE`        | yes      | The Go module path                                                                      |                                            |
| `APP_NAME`         | yes      | The binary name (letters, digits, `-`, `_`)                                             |                                            |
| `YOUR_NAME`        | yes      | The copyright holder in `LICENSE`                                                       |                                            |
| `ENV_PREFIX`       | no       | The prefix for the app's environment variables                                          | `APP_NAME` uppercased, `-` turned into `_` |
| `YEAR`             | no       | The copyright year in `LICENSE`                                                         | The current year                           |
| `DELETE_GIT_DIR`   | no       | `1` deletes the template's `.git` directory                                             | `0`, keep it                               |
| `GIT_INIT_DEVELOP` | no       | `1` runs `git init --initial-branch develop`; needs `DELETE_GIT_DIR=1` if `.git` exists | `0`, don't                                 |

> **Started with "Use this template"?** Leave `DELETE_GIT_DIR` and
> `GIT_INIT_DEVELOP` unset. GitHub already gave you a fresh repo with its own
> history and remote, and `DELETE_GIT_DIR=1` would delete them. Those two
> flags are for a plain `git clone` of this template, where `.git` still holds
> the template's history.

When it finishes, the script prints the remaining steps: commit the project
and tag it `v0.0.1`.

## How it works

Every file that needs a project-specific value ends in `.tmpl` and holds
tokens. `scaffold_project.sh` fills them in from the variables above:

| Token            | Filled in from |
| ---------------- | -------------- |
| `{{GO_MODULE}}`  | `GO_MODULE`    |
| `{{APP_NAME}}`   | `APP_NAME`     |
| `{{ENV_PREFIX}}` | `ENV_PREFIX`   |
| `{{YOUR_NAME}}`  | `YOUR_NAME`    |
| `{{YEAR}}`       | `YEAR`         |

The script runs these steps and stops at the first failure:

1. Checks every value and that `go`, `make`, and `docker` are available, before changing anything.
2. Fails if any `.tmpl` file holds a token it doesn't know.
3. Replaces the tokens in every `*.tmpl` file and removes the `.tmpl` suffix.
4. Fails if any token is left anywhere.
5. Runs `go -C src mod tidy`, then `make local`, `make analyze`, and `make build`.
6. Only if all of that passes: handles `DELETE_GIT_DIR` and `GIT_INIT_DEVELOP`, then deletes
   `tests/scaffold/` and itself.

The generated project is laid out like this:

| Path                | What it holds                                                                                            |
| ------------------- | -------------------------------------------------------------------------------------------------------- |
| `src/`              | The Go module: `cmd/` for the entry point, `internal/` for config and version info                       |
| `build/`            | `build.sh` and the multi-stage `Dockerfile` (`analyze`, `build`, `export`)                               |
| `tests/black_box/`  | Tests that run only the compiled binary, written in bats; see `tests/README.md` in the generated project |
| `.github/workflows` | CI that runs `build/build.sh`, skipped for Markdown-only and lint-config-only changes                    |
| `Makefile`          | Local shortcuts: `local`, `test`, `analyze`, `build`, `install`, `uninstall`                             |

`make build` places binaries under `.bin/<arch>/<os>/` for Linux, macOS, and
Windows, then runs the black-box tests against the Linux binary.

## Key Considerations

- **This README is replaced.** Rendering `README.md.tmpl` overwrites this file
  with the generated project's own README.
- **Setup takes a few minutes.** The script runs the full Docker build, which
  pulls images and downloads Go modules, so it needs network access.
- **It runs once.** If a step after rendering fails, the `.tmpl` files are
  already gone, so running the script again won't work. It prints what's left
  to finish by hand.
- **Docker names are lowercase.** A mixed-case `APP_NAME` such as `coolApp`
  keeps its casing for the binary, but `build.sh` lowercases it for the Docker
  image and compose project names, because Docker requires that.
- **Analysis reports, it never fixes.** `make analyze` and the build fail on
  unformatted code instead of rewriting it, so format on save in your editor.

## Development Considerations

### Quick Start

The raw template doesn't compile, because its Go files are still `.tmpl`. To
try a change, copy the tracked files into a scratch directory and run the
script there:

```sh
scratch_dir="$(mktemp -d)"
git ls-files | tar -cf - -T - | tar -C "${scratch_dir}" -xf -
cd "${scratch_dir}"
GO_MODULE=example.com/sampleapp APP_NAME=sampleapp YOUR_NAME="Sample Name" ./scaffold_project.sh
```

When you add a new token to the template, add it to `scaffold_project.sh`
too. Otherwise the script stops before changing anything.

### Testing

The setup script's tests are in `tests/scaffold/`. They copy the template into
a temporary directory and run the real script against it:

```sh
bats tests/scaffold
```

Two of the tests run the full build and take about a minute each. The rest
finish in well under a second.

### Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/).

Version is determined from git tags:

```bash
git describe --tags --always
```
