#!/usr/bin/env bash

set -euo pipefail

printf "\n-----Running %s-----\n" "$(basename "$0")"

DIRECTORY=".secrets" # Default value

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Removes a secrets repository submodule and associated chezmoi configuration.

Options:
  --dir <dir>           The local directory name for the submodule. Defaults to ".secrets".
  -h, --help            Display this help message and exit.
EOF
    exit 0
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                DIRECTORY="$2"
                shift 2
            else
                echo "Error: --dir requires a value." >&2
                usage
            fi
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage
            ;;
    esac
done

# --- Main Execution ---

# Check if we are in a git repository
if [ ! -d ".git" ]; then
    echo "Error: Not a git repository. Must be run from the project root." >&2
    exit 1
fi

# Check for GitHub CLI and authentication status
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

REMOTE_URL=$(git config --file .gitmodules --get "submodule.$DIRECTORY.url")
REMOTE_REPO_NAME=""
if [[ -n "$REMOTE_URL" ]]; then
    # Extract the 'user/repo' part from both SSH (git@...) and HTTPS (https://...) URLs.
    REMOTE_REPO_NAME=$(echo "$REMOTE_URL" | sed -E 's/.*github.com[:/]//; s/\.git$//')
fi

echo "This will remove the submodule in '$DIRECTORY' and its related configuration."
if [[ -n "$REMOTE_REPO_NAME" ]]; then
    echo "WARNING: This will also PERMANENTLY DELETE the remote GitHub repository: $REMOTE_REPO_NAME"
fi

read -p "Are you sure you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

echo "--> Resetting git state for submodule removal..."
# Unstage the submodule directory if it has been staged to prevent conflicts.
git restore --staged "$DIRECTORY" >/dev/null 2>&1 || true
# Forcefully reset .gitmodules to its last committed state. This is destructive
# to other uncommitted submodule changes, but ensures a clean removal.
# The file existence is checked before running checkout.
[ -f .gitmodules ] && git checkout HEAD -- .gitmodules

echo "--> Unregistering submodule '$DIRECTORY' from .git/config..."
# Directly remove the submodule's entry from the parent repository's git
# configuration. This is more robust than 'git submodule deinit', especially
# when dealing with uncommitted or inconsistent states.
git submodule deinit -f -- "$DIRECTORY" || git config --remove-section "submodule.$DIRECTORY" || true

echo "--> Removing submodule '$DIRECTORY' from git..."
# This removes the submodule from the index, the working directory,
# and also removes the section from .gitmodules.
# The -f is needed to remove it even if the working tree is modified.
git rm -f -- "$DIRECTORY" || rm -rf "$DIRECTORY"


echo "--> Removing submodule metadata from .git/modules..."
# This removes the submodule's git repository data.
# This step is crucial for a clean removal.
rm -rf ".git/modules/$DIRECTORY"

echo "--> Submodule '$DIRECTORY' removed from git."

# If we identified a remote repository, prompt for its deletion.
if [[ -n "$REMOTE_REPO_NAME" ]]; then
    echo
    echo "--- DANGER: Remote Repository Deletion ---" >&2
    echo "You are about to permanently delete the GitHub repository: $REMOTE_REPO_NAME" >&2
    echo "This action CANNOT be undone." >&2
    printf "To confirm, please type the full repository name ('%s'): " "$REMOTE_REPO_NAME"
    read -r CONFIRM_REPO_NAME
    if [[ "$CONFIRM_REPO_NAME" == "$REMOTE_REPO_NAME" ]]; then
        echo "--> Deleting GitHub repository '$REMOTE_REPO_NAME'..."
        if gh repo delete "$REMOTE_REPO_NAME" --yes; then
            echo "--> Successfully deleted remote repository."
        else
            echo "Warning: Failed to delete remote repository '$REMOTE_REPO_NAME'. You may need to delete it manually." >&2
        fi
    else
        echo "Repository name did not match. Skipping remote deletion."
    fi
fi

# The add_project.sh script also creates a .chezmoi directory for local configuration.
# Since it's tied to the submodule, it should be removed as well for a clean state.
if [ -f ".chezmoi.toml" ]; then
    echo "--> Removing .chezmoi.toml config file..."
    rm -rf ".chezmoi.toml"
fi
if [ -f "chezmoistate.boltdb" ]; then
    echo "--> Removing chezmoi db file..."
    rm -rf "chezmoistate.boltdb"
fi

echo
echo "✅ Submodule removal process complete."
echo "   Please commit the changes to finalize the removal:"
echo "   git commit -m \"feat: remove ${DIRECTORY} submodule\""