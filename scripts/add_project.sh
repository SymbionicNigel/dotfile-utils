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
    rm -rf "$PWD/${SUBMODULE_DIR:?}"
    echo "$SUBMODULE_DIR directory cleared"
    mkdir "$SUBMODULE_DIR" 1> /dev/null
    if  [ $? -ne 0 ] && [ ! -d ".secrets" ]; then
        exit 1
    elif [ $? == 0 ]; then
        echo "$PWD/$SUBMODULE_DIR created"
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

    echo "# $SUBMODULE_NAME" >> "$SUBMODULE_DIR/README.md"
    git -C "$SUBMODULE_DIR" init
    git -C "$SUBMODULE_DIR" add README.md
    git -C "$SUBMODULE_DIR" commit -m "feat: initial commit"
    git -C "$SUBMODULE_DIR" branch -M "$BRANCH"
    git -C "$SUBMODULE_DIR" remote add origin "$REMOTE_URL"
    git -C "$SUBMODULE_DIR" push -u origin "$BRANCH"
    # # Remove newly created repository to make room for submodule
    rm -rf "$PWD/${SUBMODULE_NAME:?}"
    git submodule add "$REMOTE_URL" "$SUBMODULE_DIR"
}

sudo "$SCRIPT_DIR/install_package.sh" "jq"
sudo "$SCRIPT_DIR/install_gh_cli.sh"

if ! gh auth status > /dev/null; then
    if ! gh auth login; then
        exit 1
    fi
fi

get_submodule_name
make_new_folder
initialize_submodule_repo
