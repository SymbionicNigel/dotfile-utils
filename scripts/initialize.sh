#!/bin/bash Bash

SUBMODULE_NAME=""

initialize_yadm() {
    YADM_SYMLINK_DESTINATION="/home/$USER/.local/bin/yadm"
    DOTFILES_PROJECT_LOCATION=$(readlink -e "$SCRIPT_DIR/../")
    
    git submodule update --init --recursive "$DOTFILES_PROJECT_LOCATION"
    
    if [ -L "$YADM_SYMLINK_DESTINATION" ]; then
        unlink "$YADM_SYMLINK_DESTINATION"
        echo "Unlinked file symlinked at $YADM_SYMLINK_DESTINATION"
    fi
    
    if [ -e "$YADM_SYMLINK_DESTINATION" ]; then
        rm -rf "$YADM_SYMLINK_DESTINATION"
    fi

    ln -fs "$DOTFILES_PROJECT_LOCATION/yadm/yadm" "$YADM_SYMLINK_DESTINATION"
    
    if [ -L "$YADM_SYMLINK_DESTINATION" ]; then
        echo "Symlink success"
    else
        echo "Symlink failure"
        exit 1
    fi

    git -C "$DOTFILES_PROJECT_LOCATION" submodule update --remote yadm
}

initialize_project_dotfiles() {
    # Once YADM is initialized run submodule initialization for parent repository
    if [ ! -e "$SCRIPT_DIR/../.git" ]; then
        echo "Parent Git Repository Not Initialized"
        exit 1
    fi
    echo "Parent Directory .git exists"
    # Read repository name from parent directories remote url
    PARENT_REPOSITORY_REMOTE=`git config --get remote.origin.url`
    SUBMODULE_NAME="$(basename -s ".git" "$PARENT_REPOSITORY_REMOTE")-dotfiles"
    echo "Submodule Parsed: $SUBMODULE_NAME"
    if [ ! -d "$SUBMODULE_NAME" ] || [ ! -e "$SUBMODULE_NAME/.git" ]; then
        echo "Submodule not found, adding $SUBMODULE_NAME"
        source "$SCRIPT_DIR/add_project.sh" <<< ""
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

SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

sudo sh -c "$SCRIPT_DIR/install_package.sh" gpg
initialize_yadm
# initialize_project_dotfiles
# source "$SCRIPT_DIR/bootstrap_dotfiles.sh" "$SUBMODULE_NAME"
