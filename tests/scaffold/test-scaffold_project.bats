#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../black_box/test_helper/bats-support/load"
load "${BATS_TEST_DIRNAME}/../black_box/test_helper/bats-assert/load"

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
TOKEN_PATTERN='\{\{[A-Z_]+\}\}'

# Each test works on its own copy of the template so the real repo is never touched.
setup() {
    export TEST_DIR="${BATS_TEST_TMPDIR}/project"
    export SCRIPT_PATH="${TEST_DIR}/scaffold_project.sh"

    # Docker image names must be lowercase, and the name must be unique per test
    # so teardown only ever removes what this test created.
    export APP_NAME="t${BATS_SUITE_TEST_NUMBER}-app-$$"
    export GO_MODULE="github.com/example/${APP_NAME}"
    export YOUR_NAME="Beefy Cornwallis"
    unset ENV_PREFIX YEAR DELETE_GIT_DIR GIT_INIT_DEVELOP

    copy_template_files
}

teardown() {
    remove_docker_resources
    rm -rf "${TEST_DIR}"
}

# --- helpers ---------------------------------------------------------------

copy_template_files() {
    local file_list="${BATS_TEST_TMPDIR}/files.txt"

    mkdir -p "${TEST_DIR}"
    git -C "${REPO_ROOT}" ls-files > "${file_list}"
    printf '%s\n' "scaffold_project.sh" >> "${file_list}"
    printf '%s\n' "tests/scaffold/test-scaffold_project.bats" >> "${file_list}"
    tar -C "${REPO_ROOT}" -cf - -T "${file_list}" | tar -C "${TEST_DIR}" -xf -
}

init_template_repo() {
    git -C "${TEST_DIR}" init --quiet --initial-branch develop
    git -C "${TEST_DIR}" add -A
    git -C "${TEST_DIR}" -c user.name=Tester -c user.email=tester@example.com \
        commit --quiet -m "template history"
}

# A non-template file with a token makes the script fail at the post-scan,
# right after rendering and before any build step.
plant_leftover_token() {
    printf '%s\n' '{{LEFTOVER}}' > "${TEST_DIR}/leftover.txt"
}

snapshot_tree() {
    find "${TEST_DIR}" -type f -not -path '*/.git/*' -exec cksum {} + | sort
}

remove_docker_resources() {
    local container_ids
    local network_ids
    local image_names

    container_ids=$(docker ps -aq --filter "name=${APP_NAME}-black-box" 2>/dev/null || true)
    network_ids=$(docker network ls -q --filter "name=${APP_NAME}-black-box" 2>/dev/null || true)
    image_names=$(docker images --format '{{.Repository}}:{{.Tag}}' \
        --filter "reference=${APP_NAME}_docker_image" \
        --filter "reference=${APP_NAME}-black-box-*" 2>/dev/null || true)

    remove_containers "${container_ids}"
    remove_networks "${network_ids}"
    remove_images "${image_names}"
}

remove_containers() {
    local container_ids="${1}"
    local container_id

    for container_id in ${container_ids}; do
        docker rm -f "${container_id}" >/dev/null 2>&1 || true
    done
}

remove_networks() {
    local network_ids="${1}"
    local network_id

    for network_id in ${network_ids}; do
        docker network rm "${network_id}" >/dev/null 2>&1 || true
    done
}

remove_images() {
    local image_names="${1}"
    local image_name

    for image_name in ${image_names}; do
        docker rmi "${image_name}" >/dev/null 2>&1 || true
    done
}

link_tool() {
    local tool="${1}"
    local tool_dir="${2}"
    local tool_path

    tool_path=$(command -v "${tool}")
    ln -s "${tool_path}" "${tool_dir}/${tool}"
}

assert_fully_rendered() {
    local template_files
    local tokens

    template_files=$(find "${TEST_DIR}" -type f -name '*.tmpl' -not -path '*/.git/*')
    if [ -n "${template_files}" ]; then
        printf 'leftover .tmpl files:\n%s\n' "${template_files}" >&2
        return 1
    fi

    tokens=$(grep -rnE "${TOKEN_PATTERN}" --exclude-dir=.git "${TEST_DIR}" || true)
    if [ -n "${tokens}" ]; then
        printf 'leftover tokens:\n%s\n' "${tokens}" >&2
        return 1
    fi

    return 0
}

assert_file_contains() {
    local file="${1}"
    local text="${2}"

    if ! grep -qF -- "${text}" "${file}"; then
        printf '%s does not contain: %s\n--- actual ---\n' "${file}" "${text}" >&2
        cat "${file}" >&2
        return 1
    fi

    return 0
}

assert_rendered_values() {
    assert_file_contains "${TEST_DIR}/src/go.mod" "module ${GO_MODULE}"
    assert_file_contains "${TEST_DIR}/Makefile" "APP_NAME := ${APP_NAME}"
    assert_file_contains "${TEST_DIR}/src/internal/config/config.go" "\"CUSTOM_PREFIX\""
    assert_file_contains "${TEST_DIR}/LICENSE" "Copyright (c) 1999 ${YOUR_NAME}"
    assert [ ! -e "${TEST_DIR}/Makefile.tmpl" ]
}

# --- happy path ------------------------------------------------------------

@test "scaffold_project with required vars only - renders, builds, cleans up, keeps .git" {
    init_template_repo
    local expected_prefix
    expected_prefix=$(printf '%s' "${APP_NAME}" | tr 'a-z-' 'A-Z_')
    local expected_year
    expected_year=$(date +%Y)

    run "${SCRIPT_PATH}"

    assert_success
    assert_fully_rendered
    assert [ -x "${TEST_DIR}/build/build.sh" ]
    assert [ -f "${TEST_DIR}/.bin/local/${APP_NAME}" ]
    assert_file_contains "${TEST_DIR}/README.md" "# ${APP_NAME}"
    assert [ ! -e "${TEST_DIR}/tests/scaffold" ]
    assert [ ! -e "${SCRIPT_PATH}" ]
    assert [ -d "${TEST_DIR}/.git" ]
    assert_file_contains "${TEST_DIR}/src/internal/config/config.go" "\"${expected_prefix}\""
    assert_file_contains "${TEST_DIR}/LICENSE" "Copyright (c) ${expected_year} ${YOUR_NAME}"
    assert_output --partial ".git"
    assert_output --partial "git tag"
}

@test "scaffold_project with DELETE_GIT_DIR and GIT_INIT_DEVELOP - leaves a fresh develop repo with no history" {
    init_template_repo

    run env DELETE_GIT_DIR=1 GIT_INIT_DEVELOP=1 "${SCRIPT_PATH}"

    assert_success
    assert_fully_rendered
    assert [ ! -e "${SCRIPT_PATH}" ]

    run git -C "${TEST_DIR}" symbolic-ref --short HEAD
    assert_success
    assert_output "develop"

    run git -C "${TEST_DIR}" rev-list --all --count
    assert_success
    assert_output "0"
}

# --- error paths: validation -----------------------------------------------

@test "scaffold_project with GO_MODULE unset - fails naming GO_MODULE" {
    unset GO_MODULE

    run "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: GO_MODULE is required"
}

@test "scaffold_project with APP_NAME unset - fails naming APP_NAME" {
    unset APP_NAME

    run "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: APP_NAME is required"
}

@test "scaffold_project with YOUR_NAME unset - fails naming YOUR_NAME" {
    unset YOUR_NAME

    run "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: YOUR_NAME is required"
}

@test "scaffold_project with invalid APP_NAME - fails before touching any file" {
    local before
    before=$(snapshot_tree)

    run env APP_NAME="bad name!" "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: APP_NAME"
    assert_output --partial "bad name!"
    assert_equal "$(snapshot_tree)" "${before}"
}

@test "scaffold_project with whitespace in GO_MODULE - fails naming GO_MODULE" {
    run env GO_MODULE="github.com/example/my app" "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: GO_MODULE"
}

@test "scaffold_project with invalid ENV_PREFIX - fails naming ENV_PREFIX" {
    run env ENV_PREFIX="1BAD-PREFIX" "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: ENV_PREFIX"
    assert_output --partial "1BAD-PREFIX"
}

@test "scaffold_project with APP_NAME that derives an invalid ENV_PREFIX - fails naming ENV_PREFIX" {
    run env APP_NAME="1app" "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: ENV_PREFIX"
    assert_output --partial "1APP"
}

@test "scaffold_project with DELETE_GIT_DIR=true - fails naming DELETE_GIT_DIR" {
    run env DELETE_GIT_DIR=true "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: DELETE_GIT_DIR"
    assert_output --partial "true"
}

@test "scaffold_project with GIT_INIT_DEVELOP=2 - fails naming GIT_INIT_DEVELOP" {
    run env GIT_INIT_DEVELOP=2 "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: GIT_INIT_DEVELOP"
    assert_output --partial "2"
}

@test "scaffold_project with GIT_INIT_DEVELOP=1 and existing .git but no DELETE_GIT_DIR - fails" {
    init_template_repo

    run env GIT_INIT_DEVELOP=1 "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: GIT_INIT_DEVELOP=1"
    assert_output --partial "DELETE_GIT_DIR=1"
}

@test "scaffold_project with docker missing from PATH - fails naming docker" {
    local tool_dir="${BATS_TEST_TMPDIR}/no-docker-bin"
    local tool

    mkdir -p "${tool_dir}"
    for tool in bash env dirname basename date tr find grep sed cat rm mv cp mkdir chmod git go make sort; do
        link_tool "${tool}" "${tool_dir}"
    done

    run env PATH="${tool_dir}" "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: docker"
}

@test "scaffold_project with unreachable Docker daemon - fails naming the daemon" {
    export DOCKER_HOST="unix://${BATS_TEST_TMPDIR}/no-such-docker.sock"

    run "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR: the Docker daemon"
}

@test "scaffold_project with no .tmpl files - refuses because the project is already set up" {
    find "${TEST_DIR}" -type f -name '*.tmpl' -delete

    run "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --partial "ERROR:"
    assert_output --partial "already set up"
}

# --- error paths: scans ----------------------------------------------------

@test "scaffold_project with an unknown token - fails naming file, line, and token, changing nothing" {
    printf '\n%s\n' '{{BOGUS}}' >> "${TEST_DIR}/Makefile.tmpl"
    local before
    before=$(snapshot_tree)

    run "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --regexp 'Makefile\.tmpl:[0-9]+:\{\{BOGUS\}\}'
    assert_equal "$(snapshot_tree)" "${before}"
}

@test "scaffold_project with a leftover token outside .tmpl files - fails listing it and says the project is rendered" {
    plant_leftover_token

    run "${SCRIPT_PATH}"

    assert_failure 1
    assert_output --regexp 'leftover\.txt:1:\{\{LEFTOVER\}\}'
    assert_output --partial "already rendered"
}

# --- edge cases: rendering -------------------------------------------------

@test "scaffold_project render - replaces every token with its value" {
    plant_leftover_token

    run env ENV_PREFIX=CUSTOM_PREFIX YEAR=1999 "${SCRIPT_PATH}"

    assert_failure 1
    assert_rendered_values
}

@test "scaffold_project render - writes special characters in YOUR_NAME literally" {
    local tricky_name="O'Brien & Sons | Co \\ \\1 / End"
    plant_leftover_token

    run env YOUR_NAME="${tricky_name}" YEAR=1999 "${SCRIPT_PATH}"

    assert_failure 1
    assert_file_contains "${TEST_DIR}/LICENSE" "Copyright (c) 1999 ${tricky_name}"
}

@test "scaffold_project render - keeps build/build.sh executable" {
    plant_leftover_token

    run "${SCRIPT_PATH}"

    assert_failure 1
    assert [ -x "${TEST_DIR}/build/build.sh" ]
    assert [ ! -e "${TEST_DIR}/build/build.sh.tmpl" ]
}
