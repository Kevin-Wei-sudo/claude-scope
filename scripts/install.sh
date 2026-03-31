#!/usr/bin/env bash
set -euo pipefail

OWNER="${REPO_OWNER:-Kevin-Wei-sudo}"
REPO="${REPO_NAME:-claude-scope}"
APP_NAME="ClaudeScope.app"
INSTALL_METHOD="dmg"
REF="${REPO_REF:-}"
TARGET_DIR="/Applications"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-scope-install.XXXXXX")"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

usage() {
    cat <<EOF
Usage: install.sh [options]

Options:
  --install-method <dmg|zip|git>  Installation method (default: dmg)
  --ref <tag|branch>              Git ref to install from
  --owner <github-owner>          GitHub owner (default: ${OWNER})
  --repo <github-repo>            GitHub repo (default: ${REPO})
  --target-dir <path>             Install directory (default: ${TARGET_DIR})
  -h, --help                      Show this help
EOF
}

log() {
    printf '==> %s\n' "$1"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Error: required command not found: %s\n' "$1" >&2
        exit 1
    }
}

install_app_bundle() {
    local source_app="$1"
    local destination="${TARGET_DIR}/${APP_NAME}"

    if [[ ! -d "$source_app" ]]; then
        printf 'Error: app bundle not found at %s\n' "$source_app" >&2
        exit 1
    fi

    log "Installing ${APP_NAME} to ${TARGET_DIR}"
    if [[ -w "$TARGET_DIR" ]]; then
        rm -rf "$destination"
        cp -R "$source_app" "$destination"
    else
        sudo rm -rf "$destination"
        sudo cp -R "$source_app" "$destination"
    fi

    log "Installed ${destination}"
    log "Launch it with: open \"$destination\""
}

github_release_url() {
    local artifact="$1"
    local ref="$2"
    printf 'https://github.com/%s/%s/releases/download/%s/%s\n' "$OWNER" "$REPO" "$ref" "$artifact"
}

resolve_latest_tag() {
    need_cmd curl
    local api_url="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
    local tag
    tag="$(curl -fsSL "$api_url" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
    if [[ -z "$tag" ]]; then
        printf 'Error: could not resolve latest release tag from %s\n' "$api_url" >&2
        exit 1
    fi
    printf '%s\n' "$tag"
}

install_from_dmg() {
    need_cmd curl
    need_cmd hdiutil
    local ref="$1"
    local dmg_path="${WORK_DIR}/ClaudeScope.dmg"
    local mount_point="${WORK_DIR}/mount"

    log "Downloading DMG from GitHub Releases"
    curl -fL "$(github_release_url "ClaudeScope.dmg" "$ref")" -o "$dmg_path"

    mkdir -p "$mount_point"
    log "Mounting DMG"
    hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse -quiet
    trap 'hdiutil detach "$mount_point" -quiet >/dev/null 2>&1 || true; cleanup' EXIT

    install_app_bundle "${mount_point}/${APP_NAME}"

    log "Unmounting DMG"
    hdiutil detach "$mount_point" -quiet
    trap cleanup EXIT
}

install_from_zip() {
    need_cmd curl
    need_cmd ditto
    local ref="$1"
    local zip_path="${WORK_DIR}/ClaudeScope.zip"
    local extract_dir="${WORK_DIR}/zip"

    log "Downloading ZIP from GitHub Releases"
    curl -fL "$(github_release_url "ClaudeScope.zip" "$ref")" -o "$zip_path"

    mkdir -p "$extract_dir"
    log "Extracting ZIP"
    ditto -x -k "$zip_path" "$extract_dir"

    install_app_bundle "${extract_dir}/${APP_NAME}"
}

install_from_git() {
    need_cmd git
    need_cmd make
    local clone_dir="${WORK_DIR}/repo"

    log "Cloning repository"
    git clone "https://github.com/${OWNER}/${REPO}.git" "$clone_dir"

    if [[ -n "$REF" ]]; then
        log "Checking out ${REF}"
        git -C "$clone_dir" checkout "$REF"
    fi

    log "Building and installing from source"
    (cd "$clone_dir" && make install)
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-method)
            INSTALL_METHOD="${2:-}"
            shift 2
            ;;
        --ref)
            REF="${2:-}"
            shift 2
            ;;
        --owner)
            OWNER="${2:-}"
            shift 2
            ;;
        --repo)
            REPO="${2:-}"
            shift 2
            ;;
        --target-dir)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Error: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

case "$INSTALL_METHOD" in
    dmg|zip)
        if [[ -z "$REF" ]]; then
            log "Resolving latest release"
            REF="$(resolve_latest_tag)"
        fi
        ;;
    git)
        ;;
    *)
        printf 'Error: unsupported install method: %s\n' "$INSTALL_METHOD" >&2
        usage >&2
        exit 1
        ;;
esac

log "Repository: ${OWNER}/${REPO}"
if [[ -n "$REF" ]]; then
    log "Ref: ${REF}"
fi
log "Install method: ${INSTALL_METHOD}"

case "$INSTALL_METHOD" in
    dmg)
        install_from_dmg "$REF"
        ;;
    zip)
        install_from_zip "$REF"
        ;;
    git)
        install_from_git
        ;;
esac
