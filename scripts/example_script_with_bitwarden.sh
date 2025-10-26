#!/usr/bin/env bash

# Example script showing how to use Bitwarden session in other scripts

# Source the Bitwarden session script
# Get parent repository root (handles both submodule and parent repo contexts)
PROJECT_ROOT=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Error: Not in a git repository"; exit 1; }
fi
source "$PROJECT_ROOT/dotfile-utils/scripts/source_bitwarden_session.sh" || exit 1

# Now you can use Bitwarden in your script
echo "Bitwarden session is active!"
echo "Project root: $PROJECT_ROOT"

# Example: Get a secret from Bitwarden
# SECRET=$(bw get password "item-name")

# Example: Run chezmoi commands
# chezmoi --config "$PROJECT_ROOT/.chezmoi.toml" apply
