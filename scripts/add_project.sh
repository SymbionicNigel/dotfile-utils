#!/bin/bash Bash

SUBMODULE_NAME=""
SUBMODULE_DIR=".secrets"
PARENT_REPOSITORY_REMOTE=$(git config --get remote.origin.url)
SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

get_submodule_name() {
    # Check if parent git repository has been initialized 
    if [ ! -e "./.git" ]; then
        echo "Parent Git Repository Not Initialized"
        exit 1
    fi
    # Read repository name from parent directories remote url
    SUBMODULE_NAME="$(basename -s ".git" "$PARENT_REPOSITORY_REMOTE")-dotfiles"
    
    read -er -p $'Please provide a name for the git repository\n(default will append "-dotfiles" to the parent repositories name)\n' -i "$SUBMODULE_NAME" SUBMODULE_NAME

    read -er -p $'\nPlease provide the name for the directory this new repository will be created within\n' -i "$SUBMODULE_DIR" SUBMODULE_DIR


}

make_new_folder() {
    rm -rf "$PWD/${1:?}"
    echo "$1 directory cleared"
    mkdir "$1" 1> /dev/null
    if  [ $? -ne 0 ] && [ ! -d "$1" ]; then
        exit 1
    elif [ $? == 0 ]; then
        echo "$PWD/$1 created"
    else
        echo "folder already created"
    fi
}

initialize_submodule_repo() {
    # Prompt for git default branch with default parsed from git config
    read -er -p $'\nProvide a default branch name\n' -i "$(git config --get init.defaultBranch || echo "master")" BRANCH
    if [ "$BRANCH" == "" ]; then
        echo "Invalid Branch Name"
        exit 1
    fi

    gh repo create "$SUBMODULE_NAME" --private
    REMOTE_URL=$(gh repo view "$SUBMODULE_NAME" --json "sshUrl" --jq ".sshUrl" )
    # TODO: add error checking to repo view command

    echo "# $SUBMODULE_NAME" >> "$SUBMODULE_DIR/README.md"
    GIT_CMD="git -C $SUBMODULE_DIR"
    # Initialize and add readme
    "$GIT_CMD" init
    "$GIT_CMD" add README.md
    # Alt Folder
    make_new_folder "$SUBMODULE_DIR/alt"
    "$GIT_CMD" add alt
    # Bootstrap script
    touch "$SUBMODULE_DIR/bootstrap"
    "$GIT_CMD" add bootstrap
    # Config File
    touch "$SUBMODULE_DIR/config"
    "$GIT_CMD" add config
    # Data Folder
    make_new_folder "$SUBMODULE_DIR/data"
    "$GIT_CMD" add data
    # Encryption config file and archive folder
    touch "$SUBMODULE_DIR/encrypt/config"
    make_new_folder "$SUBMODULE_DIR/encrypt/archive"
    "$GIT_CMD" add encrypt
    # Commit and Push
    "$GIT_CMD" commit -m "feat: initial commit"
    "$GIT_CMD" branch -M "$BRANCH"
    "$GIT_CMD" remote add origin "$REMOTE_URL"
    "$GIT_CMD" push -u origin "$BRANCH"
    # Remove newly created repository to make room for submodule
    rm -rf "$PWD/${SUBMODULE_NAME:?}"
    yadm submodule add "$REMOTE_URL" "$SUBMODULE_DIR"
    # TODO: Need to update core.worktree for yadm to work properly
}

sudo "$SCRIPT_DIR/install_package.sh" "jq"
sudo "$SCRIPT_DIR/install_gh_cli.sh"

if ! gh auth status > /dev/null; then
    if ! gh auth login; then
        exit 1
    fi
fi

get_submodule_name
make_new_folder "$SUBMODULE_DIR"
initialize_submodule_repo
