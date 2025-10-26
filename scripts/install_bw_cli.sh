#!/usr/bin/env bash

printf "\n-----Running %s-----\n" "$(basename "$0")"


usage() {
    cat <<EOF
Usage: $(basename "$0") [-h|--help]

Installs or updates the Bitwarden CLI ('bw') by downloading the native binary.
Checks for the latest version via GitHub CLI and updates if needed.
This script does not take any arguments other than the help flag.
EOF
    exit 0
}

get_latest_version() {
    # Use gh CLI to get latest release tag for CLI
    gh release list --repo bitwarden/clients --limit 1 --json tagName --jq '.[0].tagName' | grep -oP 'cli-v\K[0-9.]+'
}

get_installed_version() {
    if [ "$(which "bw")" ]; then
        # bw --version outputs like "2025.10.0"
        bw --version 2>/dev/null | grep -oP '[0-9.]+'
    else
        echo ""
    fi
}

install_bw_cli() {
    # Ensure required tools are available
    if ! type -p gh >/dev/null; then
        echo "Error: GitHub CLI (gh) is required but not installed"
        echo "Please run install_gh_cli.sh first"
        exit 1
    fi

    for tool in wget unzip; do
        if ! type -p $tool >/dev/null; then
            echo "$tool not found, installing..."
            sudo apt update && sudo apt-get install $tool -y
        fi
    done

    INSTALLED_VERSION=$(get_installed_version)
    LATEST_VERSION=$(get_latest_version)

    if [ -z "$LATEST_VERSION" ]; then
        echo "Error: Could not fetch latest version from GitHub"
        exit 1
    fi

    echo "Latest version: $LATEST_VERSION"

    # Test if package is installed
    if [ -n "$INSTALLED_VERSION" ]; then
        echo "Installed version: $INSTALLED_VERSION"

        if [ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]; then
            echo "Bitwarden CLI is already up to date"
            exit 0
        else
            echo "Updating Bitwarden CLI from $INSTALLED_VERSION to $LATEST_VERSION..."
        fi
    else
        echo "Bitwarden CLI not found, installing version $LATEST_VERSION..."
    fi

    #################################################
    # Instructions to install Bitwarden CLI pulled from
    # https://bitwarden.com/help/cli/

    # Download the latest Linux x64 binary
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit 1

    echo "Downloading Bitwarden CLI..."
    wget -O bw.zip "https://vault.bitwarden.com/download/?app=cli&platform=linux"

    echo "Extracting..."
    unzip -q bw.zip

    echo "Installing to /usr/local/bin..."
    chmod +x bw
    sudo mv bw /usr/local/bin/

    # Cleanup
    cd - > /dev/null || exit 1
    rm -rf "$TEMP_DIR"

    # Verify installation
    if [ "$(which "bw")" ]; then
        NEW_VERSION=$(get_installed_version)
        echo "Bitwarden CLI successfully installed!"
        echo "Version: $NEW_VERSION"
    else
        echo "Installation failed"
        exit 1
    fi

    exit 0
}


if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

install_bw_cli
