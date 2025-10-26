#!/usr/bin/env bash

# Source this file to automatically configure Bitwarden session for chezmoi
# Usage:
#   Interactive: source ./dotfile-utils/scripts/source_bitwarden_session.sh
#   In scripts:
#     PROJECT_ROOT=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
#     if [ -z "$PROJECT_ROOT" ]; then
#         PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
#     fi
#     source "$PROJECT_ROOT/dotfile-utils/scripts/source_bitwarden_session.sh" || exit 1

# Find project root using git
# Handles both submodule and parent repo contexts
PROJECT_ROOT=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
fi

if [ -z "$PROJECT_ROOT" ]; then
    echo "Error: Unable to find project root (not in a git repository)" >&2
    return 1
fi

ENV_FILE="$PROJECT_ROOT/.bitwarden.env"

# Check if Bitwarden CLI is installed
if ! command -v bw &> /dev/null; then
    echo "Error: Bitwarden CLI not installed. Run ./dotfile-utils/scripts/install_bw_cli.sh" >&2
    return 1
fi

# Load Bitwarden credentials from .bitwarden.env if it exists
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
elif [ -z "$BW_CLIENTID" ] || [ -z "$BW_CLIENTSECRET" ]; then
    echo "Error: Create .bitwarden.env: cp .bitwarden.env.example .bitwarden.env" >&2
    return 1
fi

# Check Bitwarden status and authenticate/unlock as needed
BW_STATUS=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

case "$BW_STATUS" in
    "unlocked")
        # Ensure BW_SESSION is set
        if [ -z "$BW_SESSION" ]; then
            if [ -n "$BW_PASSWORD" ]; then
                BW_SESSION=$(echo "$BW_PASSWORD" | bw unlock --raw --passwordenv BW_PASSWORD 2>/dev/null || bw unlock --raw)
                export BW_SESSION
            else
                BW_SESSION=$(bw unlock --raw)
                export BW_SESSION
            fi
        fi
        ;;
    "locked")
        if [ -n "$BW_PASSWORD" ]; then
            BW_SESSION=$(echo "$BW_PASSWORD" | bw unlock --raw --passwordenv BW_PASSWORD 2>/dev/null || bw unlock --raw)
        else
            BW_SESSION=$(bw unlock --raw)
        fi

        if [ -z "$BW_SESSION" ]; then
            echo "Error: Failed to unlock Bitwarden." >&2
            return 1
        fi
        export BW_SESSION
        ;;
    "unauthenticated")
        bw login --apikey >/dev/null 2>&1 || { echo "Error: Failed to login with API key." >&2; return 1; }

        if [ -n "$BW_PASSWORD" ]; then
            BW_SESSION=$(echo "$BW_PASSWORD" | bw unlock --raw --passwordenv BW_PASSWORD 2>/dev/null || bw unlock --raw)
        else
            BW_SESSION=$(bw unlock --raw)
        fi

        if [ -z "$BW_SESSION" ]; then
            echo "Error: Failed to unlock Bitwarden." >&2
            return 1
        fi
        export BW_SESSION
        ;;
    *)
        echo "Error: Unable to determine Bitwarden status." >&2
        return 1
        ;;
esac

# Only create alias if running interactively (not sourced by another script)
if [ -n "$PS1" ] || [ -t 0 ]; then
    alias czm='chezmoi --config ./.chezmoi.toml'
    echo "✓ Bitwarden session configured. Run: czm apply"
fi

# Export for use by other scripts
export BW_SESSION
export PROJECT_ROOT
