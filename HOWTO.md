# How to use this template

## Purpose

The purpose of this template is to create an executable binary that is run
directly on the machine from the terminal. It does not create a final image.

## Prerequisites

- Go 1.27.3 or later, for `make local`, `make test`, and `make install`
- Docker, for `make build` and `make analyze`

## Rendering the template

The template doesn't compile as-is. Every file that needs a project-specific
value ends in `.tmpl` and holds one or more tokens. To render it:

1. In every `*.tmpl` file, replace each token below with its value. Use plain
   find-and-replace, not a template engine.
2. Remove the `.tmpl` suffix from every file that has it.

| Token            | Value                                          | Example                |
| ---------------- | ---------------------------------------------- | ---------------------- |
| `{{GO_MODULE}}`  | The Go module path                             | `github.com/you/myapp` |
| `{{APP_NAME}}`   | The binary name                                | `myapp`                |
| `{{ENV_PREFIX}}` | The prefix for the app's environment variables | `MYAPP`                |
| `{{YOUR_NAME}}`  | The copyright holder in `LICENSE`              | `Jane Doe`             |
| `{{YEAR}}`       | The copyright year in `LICENSE`                | `2026`                 |

When you're done, this should print nothing:

```sh
grep -rnE '\{\{[A-Z_]+\}\}' --exclude-dir=.git --exclude=HOWTO.md . ; find . -name '*.tmpl' -not -path './.git/*'
```

Also check these by hand:

- `LICENSE` is MIT. Swap the whole text if that doesn't suit you.
- `README.md` still has the template's version and contents.
- `build/Dockerfile` pins a `golang-tooling` image. Make sure it's the latest one published at `ghcr.io/twistingmercury/golang-tooling`.

## Next steps

After rendering, you will need to do the following:

1. Run `git init`. For example, I typically run: `git init --initial-branch develop`.
2. Run `make local` - this should place a binary under this path: `[project root]/.bin/local/`
3. Run `make build` - this runs the analysis and unit tests, then places a binary under these paths:
   - `[project root]/.bin/amd64/darwin/`
   - `[project root]/.bin/amd64/linux/`
   - `[project root]/.bin/amd64/windows/`
   - `[project root]/.bin/arm64/darwin/`
   - `[project root]/.bin/arm64/linux/`

   It finishes by running the black-box tests against the Linux binary. See `tests/README.md` for how those work.
4. Add and commit the basic project. For example, I typically run: `git add -A && git commit -s -m "initial project setup"`.
   `-s` here adds a `Signed-off-by` line to the commit message.
5. Tag the initial commit. For example, I typically run: `git tag -a v0.0.1 -s -m "initial project setup"`.
   `-s` here means something different: it GPG-signs the tag, which only works if you have a signing key set up. Drop it if you don't.

Once all this is done, you can ignore this file and delete it if you wish.
