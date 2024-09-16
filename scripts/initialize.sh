#!/bin/bash Bash

install_gpg() {
    # Test if GPG is installed, return if true
    which gpg > /dev/null
    if [ $? == 0 ]; then
        echo "GPG already installed"
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
    for f in ${!osInfo[@]}
    do
        if [[ -f $f ]];then
            echo "Package manager: ${osInfo[$f]}"
            PKG_MANAGER=${osInfo[$f]}
        fi
    done
    #################################################
    echo $PKG_MANAGER
    # Install gpg and check that the install succeeded
    sudo $PKG_MANAGER install gpg -y
    if [ ! $? == 0 ]; then
        echo "Failed to install GPG, please do so manually"
        exit 1
    fi
    return 0
}


initialize_yadm() {
    # Make sure to initialize 
    git submodule init

    # Symlink the downloaded yadm script to the users path
    YADM_SYMLINK_DESTINATION="/home/$USER/.local/bin/yadm"
    if [ -L "$YADM_SYMLINK_DESTINATION" ]; then
        # File is already symlinked no action needed
        echo "File already symlinked at $YADM_SYMLINK_DESTINATION"
    elif [ -e "$YADM_SYMLINK_DESTINATION" ]; then
        # File exists already and is not a symlink
        echo "Non-symlinked located at $YADM_SYMLINK_DESTINATION"
        exit 1
    else
        # file does not exist at all 
        ln -s "$PWD/yadm/yadm" "$YADM_SYMLINK_DESTINATION"
    fi

    
    git submodule update --remote yadm
}

initialize_project_dotfiles() {
    # Once YADM is initialized run submodule initialization for parent repository
    if [ ! -e "./../.git" ]; then
        echo "Parent Git Repository Not Initialized"
        exit 1
    fi
    echo "Parent Directory .git exists"


    PARENT_REPOSITORY_REMOTE=`git -C .. config --get remote.origin.url`
    SUBMODULE_NAME="$(basename -s ".git" $PARENT_REPOSITORY_REMOTE)-dotfiles"
    echo "Sub Module Parsed: $SUBMODULE_NAME"


    if [ ! -e $SUBMODULE_NAME ]; then
        echo "Parent repository name: $SUBMODULE_NAME does not match any stored dotfile projects"
        exit 1
    fi


    git submodule update --remote $SUBMODULE_NAME
}

install_gpg
initialize_yadm
initialize_project_dotfiles