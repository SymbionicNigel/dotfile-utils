#!/usr/bin/env bash
#
# This script ensures a personal fork and release of chezmoi exists, then installs it.
# It is designed to be idempotent and create a resilient, self-contained bootstrap process.
#
# REQUIREMENTS:
#   - `gh` (the GitHub CLI) must be installed and authenticated.
#   - The authenticated user must have permissions to create forks and releases.
#
set -euf

usage() {
    cat <<EOF
Usage: $(basename "$0") [-h|--help]

Ensures a personal fork and release of chezmoi exists, then installs a pinned version.
This script is designed to be idempotent and create a resilient, self-contained
bootstrap process. It does not take any arguments other than the help flag.

It performs the following actions:
1. Checks for a personal fork of twpayne/chezmoi and creates one if needed.
2. Checks for a specific release on the fork and mirrors it from the original if needed.
3. Downloads the correct chezmoi binary for the current OS/architecture from the fork.
4. Installs the binary to ~/.local/bin and updates the shell profile if necessary.

Requirements:
  - 'gh' (GitHub CLI) must be installed and authenticated.
  - The authenticated user must have 'repo' scope to create forks and releases.
EOF
    exit 0
}

# --- Configuration ---
# Pin the exact version of chezmoi you want to use.
# Find versions at: https://github.com/twpayne/chezmoi/releases
CHEZMOI_VERSION="v2.63.0" # Must be full version identifier!!
ORIGINAL_REPO="twpayne/chezmoi"
INSTALL_DIR="${HOME}/.local/bin"

# Define the OS/architecture pairs you want to mirror artifacts for.
# This ensures your fork has all the binaries you might need.
PLATFORMS_TO_MIRROR=(
  "linux_amd64"
  "linux_arm64"
  "darwin_arm64"
)

# --- Helper Functions ---
update_shell_profile() {
  local install_dir="$1"
  local shell_config_file=""
  local path_update_cmd=""
  local shell_name
  shell_name=$(basename "${SHELL}")

  case "${shell_name}" in
    bash) # Also handles sh, dash
      if [ -f "${HOME}/.bashrc" ]; then shell_config_file="${HOME}/.bashrc"; else shell_config_file="${HOME}/.profile"; fi
      path_update_cmd="export PATH=\"${install_dir}:\$PATH\""
      ;;
    zsh)
      shell_config_file="${HOME}/.zshrc"
      path_update_cmd="export PATH=\"${install_dir}:\$PATH\""
      ;;
    fish)
      mkdir -p "${HOME}/.config/fish"
      shell_config_file="${HOME}/.config/fish/config.fish"
      path_update_cmd="fish_add_path ${install_dir}"
      ;;
    *)
      shell_config_file="${HOME}/.profile"
      path_update_cmd="export PATH=\"${install_dir}:\$PATH\""
      ;;
  esac

  if ! grep -q "# chezmoi-install-path" "${shell_config_file}" 2>/dev/null; then
    echo "Updating ${shell_config_file} to include ${install_dir} in your PATH."
    touch "${shell_config_file}"
    printf "\n# Add chezmoi binary to PATH # chezmoi-install-path\n%s\n" "${path_update_cmd}" >> "${shell_config_file}"
    echo "Please restart your shell or run 'source ${shell_config_file}' to apply the changes."
  fi
}

ensure_fork_exists() {
  local fork_repo="$1"
  echo "Checking for fork at ${fork_repo}..."
  if ! gh repo view "${fork_repo}" >/dev/null 2>&1; then
    echo "-> Fork not found. Creating fork of ${ORIGINAL_REPO}..."
    gh repo fork "${ORIGINAL_REPO}" --clone=false --remote=false
    echo "-> Fork created successfully."
  else
    echo "-> Fork already exists."
  fi
}

ensure_release_mirrored() {
  local fork_repo="$1"
  echo "Checking for release ${CHEZMOI_VERSION} on ${fork_repo}..."
  local version_num
  version_num="${CHEZMOI_VERSION#v}"
  local tmp_dir

  if ! gh release view "${CHEZMOI_VERSION}" --repo "${fork_repo}" >/dev/null 2>&1; then
    echo "-> Release not found on fork. Mirroring from ${ORIGINAL_REPO}..."

    tmp_dir=$(mktemp -d)
    
    declare -a artifacts_to_upload

    echo "--> Downloading artifacts for defined platforms..."
    for platform in "${PLATFORMS_TO_MIRROR[@]}"; do
      local tarball_name="chezmoi_${version_num}_${platform}.tar.gz"
      echo "    - Downloading ${tarball_name}"
      if ! gh release download "${CHEZMOI_VERSION}" \
        --repo "${ORIGINAL_REPO}" \
        --pattern "${tarball_name}" \
        --output "${tmp_dir}/${tarball_name}"; then
        echo "Error: Failed to download artifact '${tarball_name}' from '${ORIGINAL_REPO}'. It may not exist for this version or platform." >&2
        exit 1
      fi
      artifacts_to_upload+=("${tmp_dir}/${tarball_name}")
    done

    echo "--> Creating release ${CHEZMOI_VERSION} on ${fork_repo}..."
    gh release create "${CHEZMOI_VERSION}" \
      --repo "${fork_repo}" \
      --title "Mirror of ${CHEZMOI_VERSION}" \
      --notes "This release is a mirror of ${ORIGINAL_REPO} release ${CHEZMOI_VERSION}." \
      "${artifacts_to_upload[@]}"

    echo "-> Release mirrored successfully."
    rm -rf "${tmp_dir}"
  else
    echo "-> Release ${CHEZMOI_VERSION} already exists on fork."

    local required_asset="chezmoi_${version_num}_${OS}_${ARCH}.tar.gz"

    echo "--> Checking if asset for this platform (${required_asset}) exists..."
    # Use gh to get asset names and grep to check for an exact, full-line match.

    if ! gh release view "${CHEZMOI_VERSION}" --repo "${fork_repo}" --json assets --jq '.assets[].name' | grep -qFx "${required_asset}"; then
      echo "--> Asset '${required_asset}' not found. Adding it to the release..."
      tmp_dir=$(mktemp -d)

      echo "    - Downloading ${required_asset} from ${ORIGINAL_REPO}"
      if ! gh release download "${CHEZMOI_VERSION}" --repo "${ORIGINAL_REPO}" --pattern "${required_asset}" --output "${tmp_dir}/${required_asset}"; then
        echo "Error: Failed to download artifact '${required_asset}' from '${ORIGINAL_REPO}'. It may not exist for this version or platform." >&2
        rm -rf "${tmp_dir}"
        exit 1
      fi

      echo "    - Uploading ${required_asset} to ${fork_repo}"
      gh release upload "${CHEZMOI_VERSION}" --repo "${fork_repo}" "${tmp_dir}/${required_asset}"

      rm -rf "${tmp_dir}"
      echo "--> Asset added successfully."
    else
      echo "--> Asset '${required_asset}' found in release."
    fi
  fi
}

# --- Pre-flight Checks ---
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI ('gh') is not installed or not in your PATH." >&2
  echo "Please run the bootstrap script to install dependencies first." >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub CLI is not authenticated." >&2
  echo "Please run 'gh auth login' before running this script." >&2
  exit 1
fi

# Dynamically determine the user's GitHub username and set the fork repository
GITHUB_USER=$(gh config get user -h github.com)
FORK_REPO="${GITHUB_USER}/chezmoi"

if command -v chezmoi >/dev/null 2>&1; then
  # chezmoi --version output is "chezmoi version v2.48.0, commit..."
  installed_version=$(chezmoi --version | awk '{print $3}' | sed 's/,//g')
  if [ "${installed_version}" = "${CHEZMOI_VERSION}" ]; then
    echo "chezmoi ${CHEZMOI_VERSION} is already installed. Nothing to do."
    exit 0
  else
    echo "Found existing chezmoi ${installed_version}. Upgrading to ${CHEZMOI_VERSION}."
  fi
else 
  echo '"chezmoi" not found. Starting fresh install.'
fi

# --- Detect OS and Architecture ---
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64 | amd64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  *) echo "Error: Unsupported architecture: ${ARCH}" >&2; exit 1 ;;
esac

# --- Mirroring and Installation ---
echo "--- Ensuring personal artifact mirror is up to date ---"
ensure_fork_exists "$FORK_REPO"

ensure_release_mirrored "$FORK_REPO"

# --- Download and Install ---
echo "--- Installing chezmoi for local system (${OS}-${ARCH}) ---"

mkdir -p "$INSTALL_DIR"
local_tmp_dir=$(mktemp -d)

version_num_local="${CHEZMOI_VERSION#v}"
tarball_name_local="chezmoi_${version_num_local}_${OS}_${ARCH}.tar.gz"

echo "Downloading ${tarball_name_local} from ${FORK_REPO} release ${CHEZMOI_VERSION}..."
gh release download "${CHEZMOI_VERSION}" \
  --repo "${FORK_REPO}" \
  --pattern "${tarball_name_local}" \
  --output "${local_tmp_dir}/${tarball_name_local}"

tar -xzf "${local_tmp_dir}/${tarball_name_local}" -C "${local_tmp_dir}" "chezmoi"
mv "${local_tmp_dir}/chezmoi" "${INSTALL_DIR}/chezmoi"
chmod +x "${INSTALL_DIR}/chezmoi"

# --- Cleanup ---
rm -rf "${local_tmp_dir}"

# --- Post-install ---
export PATH="${INSTALL_DIR}:${PATH}"
update_shell_profile "${INSTALL_DIR}"

# --- Verification ---
echo
echo "chezmoi ${CHEZMOI_VERSION} installed successfully to ${INSTALL_DIR}/chezmoi"
chezmoi --version