#!/usr/bin/env bash

printf "\n-----Running %s-----\n" "$(basename "$0")"

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
    if [ ! -e "$SCRIPT_DIR/../.git" ]; then
        echo "Parent Git Repository Not Initialized"
        exit 1
    fi
    echo "Parent Directory .git exists"
    # Read repository name from parent directories remote url
    PARENT_REPOSITORY_REMOTE=`git config --get remote.origin.url`
    SUBMODULE_NAME="$(basename -s ".git" "$PARENT_REPOSITORY_REMOTE")-dotfiles"
    SUBMODULE_DIR=".secrets"
    BRANCH=$(git config --get init.defaultBranch || echo "master") 
    echo "Submodule Parsed: $SUBMODULE_NAME"

    # TODO: update this to handle better parsing of when to replace or just re-initialize submodule

    # if not a dir, not a git repo, or force is true
        # if force is true
            # clear old repo
            # remove github repo
        # call add project script
    # if is there treat as initialized and try to re-init through yadm/bootstrap



    if [ ! -d "$SUBMODULE_DIR" ] || [ ! -e "$SUBMODULE_DIR/.git" ]; then
        echo "Submodule not found, adding $SUBMODULE_NAME"

        sudo "$SCRIPT_DIR/install_gh_cli.sh"

        if ! gh auth status > /dev/null; then
            if ! gh auth login; then
                exit 1
            fi
        fi
        "$SCRIPT_DIR/add_project.sh" "$SUBMODULE_NAME" "$SUBMODULE_DIR" <<EOF
$BRANCH
EOF

        if [ $? -ne 0 ]; then
            echo "Project add failure"
            exit 1
        else
            echo "Project add success"
            exit 0
        fi
    fi
    # Once YADM is initialized run submodule initialization for parent repository
    # git submodule update --remote $SUBMODULE_NAME
}

SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

sudo "$SCRIPT_DIR/install_package.sh" "gpg"
sudo "$SCRIPT_DIR/install_gh_cli.sh"
initialize_yadm
initialize_project_dotfiles
# source "$SCRIPT_DIR/aliased_yadm.sh" "$SUBMODULE_NAME"
