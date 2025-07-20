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

# Check if the directory is a submodule.
# `git submodule status` will exit with a non-zero status if the path is not a valid submodule.
if ! git submodule status -- "$DIRECTORY" >/dev/null 2>&1; then
    echo "Error: Directory '$DIRECTORY' is not a registered submodule." >&2
    echo "You may need to remove the directory '$DIRECTORY' and '.chezmoi/.chezmoi.toml' manually if they exist." >&2
    exit 1
fi

echo "This will remove the submodule in '$DIRECTORY' and its related configuration."
read -p "Are you sure you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

echo "--> De-initializing submodule '$DIRECTORY'..."
# This removes the submodule entry from .git/config.
# The -f is needed if the submodule working tree is not present.
git submodule deinit -f -- "$DIRECTORY"

echo "--> Removing submodule '$DIRECTORY' from git..."
# This removes the submodule from the index, the working directory,
# and also removes the section from .gitmodules.
# The -f is needed to remove it even if the working tree is modified.
git rm -f -- "$DIRECTORY"

echo "--> Removing submodule metadata from .git/modules..."
# This removes the submodule's git repository data.
# This step is crucial for a clean removal.
rm -rf ".git/modules/$DIRECTORY"

echo "--> Submodule '$DIRECTORY' removed from git."

# The add_project.sh script also creates a .chezmoi.toml. We should offer to remove it.
if [ -d ".chezmoi" ]; then
    echo
    read -p "Found '.chezmoi' directory. Do you want to remove it as well? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "--> Removing .chezmoi directory"
        rm -rf ".chezmoi"
    fi
fi

echo
echo "✅ Submodule removal process complete."
echo "   Please commit the changes to finalize the removal:"
echo "   git commit -m \"feat: remove ${DIRECTORY} submodule\""