#!/usr/bin/env bash

set -euf -o pipefail

# --- Argument Parsing ---
MODE=""
# A simple loop to grab --mode
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
        MODE="$2"
        shift 2
      else
        echo "Error: --mode requires a value." >&2
        exit 1
      fi
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

# Ensure all scripts in the scripts directory are executable
chmod 754 -Rc "$SCRIPT_DIR/scripts/"

echo "--- Starting bootstrap process ---"

# 1. Install required CLI tools (e.g., GitHub CLI)
echo "Ensuring GPG is installed..."
sudo "$SCRIPT_DIR/scripts/install_package.sh" "gpg"

# 2. Install required CLI tools (e.g., GitHub CLI)
echo "Ensuring GitHub CLI is installed..."
"$SCRIPT_DIR/scripts/install_gh_cli.sh"

# 3. Install chezmoi using the dedicated script
echo "Installing/updating chezmoi..."
"$SCRIPT_DIR/scripts/install_chezmoi.sh"

# 4. Check for and set up the secrets repository submodule
echo "--- Checking for secrets repository and config file ---"
SECRETS_SUBMODULE_DIR=""
if [ -f ".chezmoi/.chezmoi.toml" ]; then
    # A local config file exists. Force chezmoi to use it to prevent it from
    # falling back to a global config (e.g., in ~/.config/chezmoi).
    # If source-path fails for any reason, the variable will be empty.
    SECRETS_SUBMODULE_DIR=$(chezmoi --config ./.chezmoi/.chezmoi.toml source-path 2>/dev/null || echo "")
fi
SHOULD_APPLY=false

# The logic below handles two main scenarios:
# 1. An existing, valid secrets submodule is found.
# 2. No submodule is found, and the user is prompted to create one.

if [ -n "$SECRETS_SUBMODULE_DIR" ] && [ -d "$SECRETS_SUBMODULE_DIR" ] && [ -d "$SECRETS_SUBMODULE_DIR/.git" ]; then
    echo "Secrets repository found at './${SECRETS_SUBMODULE_DIR}'. Initializing..."
    git submodule update --init --recursive "$SECRETS_SUBMODULE_DIR"
    SHOULD_APPLY=true
else
    if [ -n "$SECRETS_SUBMODULE_DIR" ]; then
        echo "Warning: .chezmoi/.chezmoi.toml found, but secrets repository at './${SECRETS_SUBMODULE_DIR}' is missing or not a valid submodule."
    fi

    read -p "No secrets repository configured or found. Would you like to create/add one now? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Launching secrets repository setup..."

        # Ask for the directory name for the new submodule, defaulting to .secrets
        submodule_dir=".secrets"
        read -er -p "Enter the local directory name for the secrets submodule: " -i "$submodule_dir" submodule_dir

        # Pre-flight check: Validate that the target directory doesn't already exist
        if [ -e "$submodule_dir" ]; then
            echo "Error: A file or directory named '${submodule_dir}' already exists in the project root." >&2
            echo "Please remove it or choose a different name." >&2
            exit 1
        fi

        # Build arguments to pass to the add_project.sh script
        add_project_args=("--dir" "$submodule_dir")
        if [ -n "$MODE" ]; then
            add_project_args+=("--mode" "$MODE")
        fi
        "$SCRIPT_DIR/scripts/add_project.sh" "${add_project_args[@]}"
        SHOULD_APPLY=true
    else 
      exit 0
    fi
fi

if [ "$SHOULD_APPLY" = true ]; then
    echo "--- Applying chezmoi configuration ---"
    chezmoi --config "./.chezmoi/.chezmoi.toml" apply
fi

echo "--- Bootstrap complete ---"