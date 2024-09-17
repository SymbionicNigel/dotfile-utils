#!/bin/bash Bash

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
        if [ -L "$YADM_SYMLINK_DESTINATION" ]; then
            # File is already symlinked no action needed
            echo "Symlink success"
        else
            echo "Symlink failure"
            exit 1
        fi
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


    # Read repository name from parent directories remote url
    PARENT_REPOSITORY_REMOTE=`git -C .. config --get remote.origin.url`
    SUBMODULE_NAME="$(basename -s ".git" $PARENT_REPOSITORY_REMOTE)-dotfiles"
    echo "Submodule Parsed: $SUBMODULE_NAME"

    if [ ! -d $SUBMODULE_NAME ] || [ ! -e "$SUBMODULE_NAME/.git" ]; then
        echo "Submodule not found, adding $SUBMODULE_NAME"
        source $PWD/scripts/add_project.sh <<< ""

        if [ $? -ne 0 ]; then
            echo "Project add failure"
            exit 1
        else
            echo "Project add success"
            exit 0
        fi
    fi

    # git submodule update --remote $SUBMODULE_NAME
}

source $PWD/scripts/install_package.sh gpg
initialize_yadm
initialize_project_dotfiles