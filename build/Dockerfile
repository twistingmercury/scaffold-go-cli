# You will need to ensure that the pinned image is the latest published image in ghcr.io/twistingmercury/golang-tooling
FROM ghcr.io/twistingmercury/golang-tooling:go1.27.3@sha256:d9246e817f7288970bc956e6e41fabec69bb4be10eb287c9b14f4ca769fd5a05 AS builder

ARG BUILD_VER
ARG BUILD_DATE
ARG BUILD_COMMIT

ARG APP_NAME
ARG MODULE_NAME

ARG LD_FLAGS="-s -w -X '${MODULE_NAME}/internal/version.version=${BUILD_VER}' -X '${MODULE_NAME}/internal/version.buildDate=${BUILD_DATE}' -X '${MODULE_NAME}/internal/version.gitCommit=${BUILD_COMMIT}'"

WORKDIR /workspace

COPY src/go.mod src/go.sum ./
# go mod verify asserts downloads match committed checksums without mutating go.sum.
# Run `go -C src mod tidy` locally if you need to update go.sum.
RUN go mod verify

COPY src/ .

# Run linters, formatters, security scanners, etc
RUN goimports -w .
RUN golangci-lint run
RUN govulncheck ./...
RUN gosec ./...

RUN CGO_ENABLED=1 go test -race ./...

RUN CGO_ENABLED=0 GOARCH=amd64 GOOS=darwin go build --ldflags "${LD_FLAGS}" -o /.bin/amd64/darwin/${APP_NAME} ./cmd/...
RUN CGO_ENABLED=0 GOARCH=arm64 GOOS=darwin go build --ldflags "${LD_FLAGS}" -o /.bin/arm64/darwin/${APP_NAME} ./cmd/...
RUN CGO_ENABLED=0 GOARCH=amd64 GOOS=linux go build --ldflags "${LD_FLAGS}" -o /.bin/amd64/linux/${APP_NAME} ./cmd/...
RUN CGO_ENABLED=0 GOARCH=arm64 GOOS=linux go build --ldflags "${LD_FLAGS}" -o /.bin/arm64/linux/${APP_NAME} ./cmd/...
RUN CGO_ENABLED=0 GOARCH=amd64 GOOS=windows go build --ldflags "${LD_FLAGS}" -o /.bin/amd64/windows/${APP_NAME}.exe ./cmd/...


#---------------------------------------------------------------------
FROM scratch AS export

COPY --from=builder /.bin/ .