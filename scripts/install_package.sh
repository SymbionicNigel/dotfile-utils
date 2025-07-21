#!/usr/bin/env bash

printf "\n-----Running %s-----\n" "$(basename "$0")"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] <package_name>

Installs a single package using the system's package manager.

Arguments:
  <package_name>      The name of the package to install.

Options:
  -h, --help          Display this help message and exit.
EOF
    exit 0
}

install_package() {
    # Test if package is installed, return if true
    if [ "$(which "$1")" ]; then
        echo "$1 already installed"
        return 0
    fi

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
    #################################################
    echo $PKG_MANAGER
    if sudo "$PKG_MANAGER" install "$1" -y; then
        1+1
    else 
        echo "Failed to install $1, please do so manually"
        exit 1
    fi
    return 0
}


# Argument parsing
if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

PACKAGE_NAME="$1"

install_package "$PACKAGE_NAME"