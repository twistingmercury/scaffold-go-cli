#!/usr/bin/env bash

# Sets up a new project from this template: renders every *.tmpl file, verifies
# the build, then removes the template-only files (including this script).
#
# Required env vars: GO_MODULE, APP_NAME, YOUR_NAME
# Optional env vars: ENV_PREFIX, YEAR, DELETE_GIT_DIR (0|1), GIT_INIT_DEVELOP (0|1)
#
# Example:
#   GO_MODULE=github.com/twistingmercury/coolApp APP_NAME=coolApp \
#   YOUR_NAME="Beefy Cornwallis" DELETE_GIT_DIR=1 ./scaffold_project.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"
PROJECT_ROOT="${SCRIPT_DIR}"
GIT_DIR_PATH="${PROJECT_ROOT}/.git"

readonly TOKEN_PATTERN='\{\{[A-Z_]+\}\}'
readonly KNOWN_TOKEN_PATTERN='\{\{(GO_MODULE|APP_NAME|ENV_PREFIX|YOUR_NAME|YEAR)\}\}'

YEAR="${YEAR:-$(date +%Y)}"
DELETE_GIT_DIR="${DELETE_GIT_DIR:-0}"
GIT_INIT_DEVELOP="${GIT_INIT_DEVELOP:-0}"

# --- step 1: validate_args ---------------------------------------------------

validate_args() {
    if ! validate_required_vars; then
        return 1
    fi

    if ! validate_app_name; then
        return 1
    fi

    if ! validate_go_module; then
        return 1
    fi

    resolve_env_prefix

    if ! validate_env_prefix; then
        return 1
    fi

    if ! validate_flag DELETE_GIT_DIR "${DELETE_GIT_DIR}"; then
        return 1
    fi

    if ! validate_flag GIT_INIT_DEVELOP "${GIT_INIT_DEVELOP}"; then
        return 1
    fi

    if is_git_init_blocked; then
        printf "ERROR: GIT_INIT_DEVELOP=1 needs DELETE_GIT_DIR=1 because %s already exists\n" "${GIT_DIR_PATH}" >&2
        return 1
    fi

    if ! validate_tools; then
        return 1
    fi

    if ! validate_templates_exist; then
        return 1
    fi

    return 0
}

validate_required_vars() {
    if [ -z "${GO_MODULE:-}" ]; then
        printf "ERROR: GO_MODULE is required (for example github.com/you/myapp)\n" >&2
        return 1
    fi

    if [ -z "${APP_NAME:-}" ]; then
        printf "ERROR: APP_NAME is required (for example myapp)\n" >&2
        return 1
    fi

    if [ -z "${YOUR_NAME:-}" ]; then
        printf "ERROR: YOUR_NAME is required (the copyright holder)\n" >&2
        return 1
    fi

    return 0
}

validate_app_name() {
    case "${APP_NAME}" in
        *[!A-Za-z0-9_-]*)
            printf "ERROR: APP_NAME may only contain letters, digits, '-' and '_': %s\n" "${APP_NAME}" >&2
            return 1
            ;;
    esac

    return 0
}

validate_go_module() {
    case "${GO_MODULE}" in
        *[[:space:]]*)
            printf "ERROR: GO_MODULE must not contain whitespace: %s\n" "${GO_MODULE}" >&2
            return 1
            ;;
    esac

    return 0
}

# The default is the app name in capitals so the prefix reads like an
# environment variable: coolApp -> COOLAPP, my-app -> MY_APP.
resolve_env_prefix() {
    if [ -n "${ENV_PREFIX:-}" ]; then
        return 0
    fi

    ENV_PREFIX=$(printf '%s' "${APP_NAME}" | tr 'a-z-' 'A-Z_')

    return 0
}

validate_env_prefix() {
    case "${ENV_PREFIX}" in
        [0-9]*|*[!A-Za-z0-9_]*)
            printf "ERROR: ENV_PREFIX is not a valid environment variable name: %s\n" "${ENV_PREFIX}" >&2
            return 1
            ;;
    esac

    return 0
}

validate_flag() {
    local flag_name="${1}"
    local flag_value="${2}"

    case "${flag_value}" in
        0|1)
            return 0
            ;;
    esac

    printf "ERROR: %s must be unset, 0, or 1: %s\n" "${flag_name}" "${flag_value}" >&2
    return 1
}

# Re-creating a repo over an existing one would silently keep the old history,
# so the caller has to say the old one goes away.
is_git_init_blocked() {
    if [ ! -e "${GIT_DIR_PATH}" ]; then
        return 1
    fi

    if [ "${DELETE_GIT_DIR}" = 1 ]; then
        return 1
    fi

    [ "${GIT_INIT_DEVELOP}" = 1 ]
}

validate_tools() {
    if ! validate_command_exists go; then
        return 1
    fi

    if ! validate_command_exists make; then
        return 1
    fi

    if ! validate_command_exists docker; then
        return 1
    fi

    if [ "${GIT_INIT_DEVELOP}" = 1 ]; then
        if ! validate_command_exists git; then
            return 1
        fi
    fi

    if ! docker info >/dev/null 2>&1; then
        printf "ERROR: the Docker daemon is not responding; start Docker and try again\n" >&2
        return 1
    fi

    return 0
}

validate_command_exists() {
    local command_name="${1}"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf "ERROR: %s is not on PATH\n" "${command_name}" >&2
        return 1
    fi

    return 0
}

validate_templates_exist() {
    local template_files

    template_files=$(find_template_files)
    if [ -z "${template_files}" ]; then
        printf "ERROR: no *.tmpl files found in %s; the project is already set up\n" "${PROJECT_ROOT}" >&2
        return 1
    fi

    return 0
}

find_template_files() {
    find "${PROJECT_ROOT}" -type f -name '*.tmpl' -not -path "${GIT_DIR_PATH}/*" | sort

    return 0
}

# --- step 2: pre-scan --------------------------------------------------------

# Runs before anything is changed, so a typo in a token never leaves the
# project half rendered.
check_for_unknown_tokens() {
    local unknown_tokens

    unknown_tokens=$(list_unknown_tokens)
    if [ -z "${unknown_tokens}" ]; then
        return 0
    fi

    printf "ERROR: unknown tokens in .tmpl files (nothing was changed):\n%s\n" "${unknown_tokens}" >&2
    return 1
}

list_unknown_tokens() {
    local template_files
    local template_file

    template_files=$(find_template_files)

    while IFS= read -r template_file; do
        print_unknown_tokens_in_file "${template_file}"
    done <<EOF
${template_files}
EOF

    return 0
}

print_unknown_tokens_in_file() {
    local template_file="${1}"
    local all_tokens
    local unknown_tokens
    local token_hit

    all_tokens=$(grep -noE "${TOKEN_PATTERN}" "${template_file}" || true)
    if [ -z "${all_tokens}" ]; then
        return 0
    fi

    unknown_tokens=$(printf '%s\n' "${all_tokens}" | grep -vE ":${KNOWN_TOKEN_PATTERN}\$" || true)
    if [ -z "${unknown_tokens}" ]; then
        return 0
    fi

    while IFS= read -r token_hit; do
        printf "  %s:%s\n" "${template_file}" "${token_hit}"
    done <<EOF
${unknown_tokens}
EOF

    return 0
}

# --- step 3: render ----------------------------------------------------------

render_templates() {
    local sed_script
    local template_files
    local template_file

    sed_script=$(build_sed_script)
    template_files=$(find_template_files)

    while IFS= read -r template_file; do
        if ! render_template_file "${template_file}" "${sed_script}"; then
            return 1
        fi
    done <<EOF
${template_files}
EOF

    return 0
}

# Prints one substitution per token. Every value is escaped first because the
# user's text ends up inside a sed command.
build_sed_script() {
    local escaped_module
    local escaped_app_name
    local escaped_env_prefix
    local escaped_your_name
    local escaped_year

    escaped_module=$(escape_for_sed "${GO_MODULE}")
    escaped_app_name=$(escape_for_sed "${APP_NAME}")
    escaped_env_prefix=$(escape_for_sed "${ENV_PREFIX}")
    escaped_your_name=$(escape_for_sed "${YOUR_NAME}")
    escaped_year=$(escape_for_sed "${YEAR}")

    printf '%s\n' "s|{{GO_MODULE}}|${escaped_module}|g"
    printf '%s\n' "s|{{APP_NAME}}|${escaped_app_name}|g"
    printf '%s\n' "s|{{ENV_PREFIX}}|${escaped_env_prefix}|g"
    printf '%s\n' "s|{{YOUR_NAME}}|${escaped_your_name}|g"
    printf '%s\n' "s|{{YEAR}}|${escaped_year}|g"

    return 0
}

# Backslash, ampersand, and the '|' delimiter are the characters sed treats
# specially in a replacement.
escape_for_sed() {
    local raw_value="${1}"

    printf '%s' "${raw_value}" | sed -e 's/[\\&|]/\\&/g'

    return 0
}

# No `sed -i`: its syntax differs between GNU and BSD. The copy comes first so
# the work file inherits the template's permissions (build.sh must stay
# executable); sed then only replaces the contents.
render_template_file() {
    local template_file="${1}"
    local sed_script="${2}"
    local rendered_file="${template_file%.tmpl}"
    local work_file="${rendered_file}.rendering"

    if ! cp -p "${template_file}" "${work_file}"; then
        printf "ERROR: could not create %s\n" "${work_file}" >&2
        return 1
    fi

    if ! sed -e "${sed_script}" "${template_file}" > "${work_file}"; then
        rm -f "${work_file}"
        printf "ERROR: could not render %s\n" "${template_file}" >&2
        return 1
    fi

    if ! mv "${work_file}" "${rendered_file}"; then
        printf "ERROR: could not move %s to %s\n" "${work_file}" "${rendered_file}" >&2
        return 1
    fi

    if ! rm "${template_file}"; then
        printf "ERROR: could not remove %s\n" "${template_file}" >&2
        return 1
    fi

    return 0
}

# --- steps 4-7: finish the rendered project ----------------------------------

complete_project() {
    if ! check_for_leftover_tokens; then
        return 1
    fi

    if ! tidy_go_module; then
        return 1
    fi

    if ! verify_build; then
        return 1
    fi

    if ! clean_up; then
        return 1
    fi

    return 0
}

# The script and its tests describe tokens on purpose, so they are not searched.
# The template's README.md mentions tokens too, but rendering README.md.tmpl has
# already replaced it by now.
check_for_leftover_tokens() {
    local leftover_tokens

    leftover_tokens=$(list_leftover_tokens || true)
    if [ -z "${leftover_tokens}" ]; then
        return 0
    fi

    printf "ERROR: tokens are still present after rendering:\n%s\n" "${leftover_tokens}" >&2
    return 1
}

list_leftover_tokens() {
    find "${PROJECT_ROOT}" -type f \
        -not -path "${GIT_DIR_PATH}/*" \
        -not -path "${PROJECT_ROOT}/tests/scaffold/*" \
        -not -path "${SCRIPT_PATH}" \
        -exec grep -nE "${TOKEN_PATTERN}" /dev/null {} +
}

tidy_go_module() {
    if ! go -C "${PROJECT_ROOT}/src" mod tidy; then
        printf "ERROR: go mod tidy failed\n" >&2
        return 1
    fi

    return 0
}

verify_build() {
    local make_target

    for make_target in local analyze build; do
        if ! run_make_target "${make_target}"; then
            return 1
        fi
    done

    return 0
}

run_make_target() {
    local make_target="${1}"

    if ! make -C "${PROJECT_ROOT}" "${make_target}"; then
        printf "ERROR: make %s failed\n" "${make_target}" >&2
        return 1
    fi

    return 0
}

# Everything here is deleted only after the build passed, so a failed run
# leaves the helpers a person needs to retry by hand.
clean_up() {
    if ! remove_git_directory; then
        return 1
    fi

    if ! init_git_repo; then
        return 1
    fi

    if ! remove_setup_files; then
        return 1
    fi

    remove_this_script

    return 0
}

remove_git_directory() {
    if [ "${DELETE_GIT_DIR}" != 1 ]; then
        return 0
    fi

    if ! rm -rf "${GIT_DIR_PATH}"; then
        printf "ERROR: could not delete %s\n" "${GIT_DIR_PATH}" >&2
        return 1
    fi

    return 0
}

init_git_repo() {
    if [ "${GIT_INIT_DEVELOP}" != 1 ]; then
        return 0
    fi

    if ! git -C "${PROJECT_ROOT}" init --initial-branch develop; then
        printf "ERROR: git init failed\n" >&2
        return 1
    fi

    return 0
}

remove_setup_files() {
    if ! rm -rf "${PROJECT_ROOT}/tests/scaffold"; then
        printf "ERROR: could not delete tests/scaffold\n" >&2
        return 1
    fi

    return 0
}

# A warning, not an error: Windows can hold a lock on a running script, and by
# this point the project itself is finished.
remove_this_script() {
    if ! rm -f "${SCRIPT_PATH}"; then
        printf "WARNING: could not delete %s; please delete it manually\n" "${SCRIPT_PATH}" >&2
    fi

    return 0
}

# --- step 8: report ----------------------------------------------------------

print_success() {
    local step_number=1

    printf "\nSUCCESS: %s is set up.\n" "${APP_NAME}"

    if is_template_git_dir_kept; then
        printf "\nThe existing .git directory was kept, so it still holds the template's history.\n"
    fi

    printf "\nNext steps:\n"

    if [ ! -e "${GIT_DIR_PATH}" ]; then
        printf "  %s. git init --initial-branch develop\n" "${step_number}"
        step_number=$((step_number + 1))
    fi

    printf "  %s. git add -A && git commit -s -m \"initial project setup\"\n" "${step_number}"
    step_number=$((step_number + 1))

    printf "  %s. git tag -a v0.0.1 -s -m \"initial project setup\" (drop -s if you have no GPG signing key)\n" "${step_number}"

    return 0
}

is_template_git_dir_kept() {
    if [ ! -e "${GIT_DIR_PATH}" ]; then
        return 1
    fi

    [ "${DELETE_GIT_DIR}" != 1 ]
}

# Re-running would fail on "no .tmpl files", so the person needs to know what
# to finish by hand instead.
print_rendered_failure_help() {
    local step_number=5

    printf "\nThe project is already rendered (the .tmpl files are gone), so do not run this script again.\n" >&2
    printf "To finish by hand:\n" >&2
    printf "  1. Fix the problem reported above.\n" >&2
    printf "  2. Run: go -C src mod tidy\n" >&2
    printf "  3. Run: make local, then make analyze, then make build\n" >&2
    printf "  4. Delete tests/scaffold and scaffold_project.sh\n" >&2

    if [ "${DELETE_GIT_DIR}" = 1 ]; then
        printf "  %s. Delete the .git directory\n" "${step_number}" >&2
        step_number=$((step_number + 1))
    fi

    if [ "${GIT_INIT_DEVELOP}" = 1 ]; then
        printf "  %s. Run: git init --initial-branch develop\n" "${step_number}" >&2
    fi

    return 0
}

main() {
    if ! validate_args; then
        return 1
    fi

    if ! check_for_unknown_tokens; then
        return 1
    fi

    if ! render_templates; then
        return 1
    fi

    if ! complete_project; then
        print_rendered_failure_help
        return 1
    fi

    print_success

    return 0
}

main "$@"
