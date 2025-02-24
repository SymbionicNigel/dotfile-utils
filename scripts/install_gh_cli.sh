#!/usr/bin/env bash

install_gh_cli() {
    # Package manager parsing pulled from
    # https://unix.stackexchange.com/questions/46081/identifying-the-system-package-manager
    declare -A osInfo;
    osInfo[/etc/redhat-release]=yum
    osInfo[/etc/arch-release]=pacman
    osInfo[/etc/gentoo-release]=emerge
    osInfo[/etc/SuSE-release]=zypp
    osInfo[/etc/debian_version]=apt-get
    osInfo[/etc/alpine-release]=apk
    PKG_MANAGER=""
    for f in "${!osInfo[@]}"
    do
        if [[ -f $f ]];then
            echo "Package manager: ${osInfo[$f]}"
            PKG_MANAGER=${osInfo[$f]}
        fi
    done

    # Test if package is installed, return if true
    if [ "$(which "gh")" ]; then
        # Update if installed
        case "$PKG_MANAGER" in
            'apt-get')
                sudo apt-get update > /dev/null
                sudo apt-get install gh > /dev/null
                ;;
            *)
                ;;
        esac
        echo "GH CLI already installed"
        exit 0
    fi


    #################################################
    # Instructions to install github cli pulled from
    # https://github.com/cli/cli/blob/trunk/docs/install_linux.md

    case "$PKG_MANAGER" in
        'apt-get')
            echo 'Installing GitHub CLI using apt'
            (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
            && sudo mkdir -p -m 755 /etc/apt/keyrings \
            && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
            && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
            && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
            && sudo apt update \
            && sudo apt install gh -y
            ;;
        *)
            printf $'\nUnsupported Package Management system\n'
            exit 1
            ;;
    esac
    exit 0
}
install_gh_cli