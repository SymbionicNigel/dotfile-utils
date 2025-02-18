#!/bin/bash Bash

SUBMODULE_NAME=""
PARENT_REPOSITORY_REMOTE=`git -C .. config --get remote.origin.url`

get_submodule_name() {
    # Check if parent git repository has been initialized 
    if [ ! -e "./../.git" ]; then
        echo "Parent Git Repository Not Initialized"
        exit 1
    fi
    # Read repository name from parent directories remote url
    SUBMODULE_NAME="$(basename -s ".git" "$PARENT_REPOSITORY_REMOTE")-dotfiles"
    
    read -er -p $'\nPlease provide the name of the project\n(default will append "-dotfiles" to the parent repositories name )\n' -i "$SUBMODULE_NAME" SUBMODULE_NAME
}

make_new_folder() {
    rm -rf "$PWD/.secrets"
    echo ".secrets directory cleared"
    mkdir ".secrets" 1> /dev/null
    if  [ $? -ne 0 ] && [ ! -d ".secrets" ]; then
        exit 1
    elif [ $? == 0 ]; then
        echo "$PWD/.secrets created"
    else
        echo "folder already created"
    fi
}

initialize_submodule_repo() {
    SUBMODULE_DIR="$PWD/.secrets"
    # Prompt for git remote with default parsed from parent repository
    read -er -p $'\nProvide a git remote to store this new module in:\n' -i "$(dirname "$PARENT_REPOSITORY_REMOTE")/$SUBMODULE_NAME.git" REMOTE_URL
    # Prompt for git default branch with default parsed from git config
    read -er -p $'\nProvide a default branch name\n' -i "$(git config --get init.defaultBranch || echo "master")" BRANCH
    if [ "$BRANCH" == "" ]; then
        echo "Invalid Branch Name"
        exit 1
    fi

    # TODO: add in step to go create the repo in github/gitlab
    # TODO: Make the repository created here private by default, Look at this gist for inspiration for github https://gist.github.com/alexpchin/dc91e723d4db5018fef8
    URL_ENCODED_REPO_NAME=$(jq -rn --arg x "$SUBMODULE_NAME" '$x|@uri')
    read -r -p "Please follow this link to create a !!!PRIVATE!!! repository with the correct name of $SUBMODULE_NAME"$'\n'"https://github.com/new?name=$URL_ENCODED_REPO_NAME"$'\nPress enter when ready...'

    echo "# $SUBMODULE_NAME" >> "$SUBMODULE_NAME/README.md"
    git -C "$SUBMODULE_DIR" init
    git -C "$SUBMODULE_DIR" add README.md
    git -C "$SUBMODULE_DIR" commit -m "feat: initial commit"
    git -C "$SUBMODULE_DIR" branch -M "$BRANCH"
    git -C "$SUBMODULE_DIR" remote add origin "$REMOTE_URL"
    git -C "$SUBMODULE_DIR" push -u origin "$BRANCH"
    # Remove newly created repository to make room for submodule
    rm -rf "$PWD/${SUBMODULE_NAME:?}"
    git submodule add "$REMOTE_URL"
}

source "./install_package.sh" jq
get_submodule_name
make_new_folder
initialize_submodule_repo
