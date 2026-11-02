# How to use this template

## Purpose

The purpose of this template is to create an executable binary that is run
directly on the machine from the terminal. It does not create a final image.

## Prerequisites

- Go 1.27.3 or later, for `make local`, `make test`, and `make install`
- Docker, for `make build` and `make analyze`

## Setting up a project

Run `scaffold_project.sh` from the project root, configured with environment
variables:

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

The script:

1. Checks every value and that `go`, `make`, and `docker` are available, before changing anything.
2. Fails if any `.tmpl` file holds a token it doesn't know.
3. Replaces the tokens in every `*.tmpl` file and removes the `.tmpl` suffix.
4. Fails if any token is left anywhere.
5. Runs `go -C src mod tidy`, then `make local`, `make analyze`, and `make build`.
6. Only if all of that passes: handles `DELETE_GIT_DIR` and `GIT_INIT_DEVELOP`, then deletes
   this file, `tests/scaffold/`, and itself.

It takes a few minutes, because `make build` runs the full pipeline. If a step
after rendering fails, the script says what's left to finish by hand. Running
it again won't work, because the `.tmpl` files are already gone.

### Tokens

Every file that needs a project-specific value ends in `.tmpl`. These are the
tokens the script replaces:

| Token            | Filled in from |
| ---------------- | -------------- |
| `{{GO_MODULE}}`  | `GO_MODULE`    |
| `{{APP_NAME}}`   | `APP_NAME`     |
| `{{ENV_PREFIX}}` | `ENV_PREFIX`   |
| `{{YOUR_NAME}}`  | `YOUR_NAME`    |
| `{{YEAR}}`       | `YEAR`         |

If you add a new token to the template, teach `scaffold_project.sh` about it
too. Otherwise the script stops before changing anything. Its tests live in
`tests/scaffold/` and run with `bats tests/scaffold`.

Also check these by hand:

- `LICENSE` is MIT. Swap the whole text if that doesn't suit you.
- `README.md` still has the template's version and contents.
- `build/Dockerfile` pins a `golang-tooling` image. Make sure it's the latest one published at `ghcr.io/twistingmercury/golang-tooling`.

## Next steps

The script prints these when it's done:

1. Run `git init --initial-branch develop`, if you didn't set `GIT_INIT_DEVELOP=1`.
2. Add and commit the basic project. For example, I typically run: `git add -A && git commit -s -m "initial project setup"`.
   `-s` here adds a `Signed-off-by` line to the commit message.
3. Tag the initial commit. For example, I typically run: `git tag -a v0.0.1 -s -m "initial project setup"`.
   `-s` here means something different: it GPG-signs the tag, which only works if you have a signing key set up. Drop it if you don't.

`make build` places binaries under `.bin/<arch>/<os>/` for linux, darwin, and
windows, and finishes by running the black-box tests against the Linux binary.
See `tests/README.md` for how those work.
