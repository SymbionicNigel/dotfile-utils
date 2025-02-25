#!/usr/bin/env bash

printf "\n-----Running %s-----\n" "$(basename "$0")"

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


install_package "$1"