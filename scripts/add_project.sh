#!/usr/bin/env bash

printf "\n-----Running %s-----\n" "$(basename "$0")"

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

    if [ -z "$1" ] && [ -n "$2" ] || [ -z "$2" ] && [ -n "$1" ]; then
        echo "Invalid arguments passed to script: either both or neither SUBMODULE_NAME and SUBMODULE_DIR should be passed"
        exit 1
    fi
    
    if [ -z "$1" ]; then
        read -er -p $'Please provide a name for the git repository\n(default will append "-dotfiles" to the parent repositories name)\n' -i "$SUBMODULE_NAME" SUBMODULE_NAME
    else 
        SUBMODULE_NAME=$1
    fi
    
    if [ -z "$1" ]; then
        read -er -p $'\nPlease provide the name for the directory this new repository will be created within\n' -i "$SUBMODULE_DIR" SUBMODULE_DIR
    else
        SUBMODULE_DIR=$2
    fi
}

make_new_folder() {
    rm -rf "$PWD/${1:?}"
    mkdir "$1" 1> /dev/null
    if  [ $? -ne 0 ] && [ ! -d "$1" ]; then
        exit 1
    elif [ $? == 0 ]; then
        echo "$PWD/$1 created"
    else
        echo "$PWD/$1 already exists"
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
    if ! REMOTE_URL=$(gh repo view "$SUBMODULE_NAME" --json "sshUrl" --jq ".sshUrl" 2>&1); then
        echo "Failure to create Github Repo: $SUBMODULE_NAME"
        echo "Repo View Error: $REMOTE_URL"
        exit 1
    fi

    # Initialize and add readme
    git -C "$SUBMODULE_DIR" init

    cat << EOF > "$SUBMODULE_DIR/.gitignore"
encrypt/archive/*
!encrypt/archive/.gitkeep
EOF
    git -C "$SUBMODULE_DIR" add .gitignore

    echo "# $SUBMODULE_NAME" >> "$SUBMODULE_DIR/README.md"
    git -C "$SUBMODULE_DIR" add README.md
    # Alt Folder
    make_new_folder "$SUBMODULE_DIR/alt"
    touch "$SUBMODULE_DIR/alt/.gitkeep"
    git -C "$SUBMODULE_DIR" add alt
    # Bootstrap script
    touch "$SUBMODULE_DIR/bootstrap"
    git -C "$SUBMODULE_DIR" add bootstrap
    # Config File
    touch "$SUBMODULE_DIR/config"
    git -C "$SUBMODULE_DIR" add config
    # Data Folder
    make_new_folder "$SUBMODULE_DIR/data"
    touch "$SUBMODULE_DIR/data/.gitkeep"
    git -C "$SUBMODULE_DIR" add data
    # Encryption config file and archive folder
    make_new_folder "$SUBMODULE_DIR/encrypt"
    touch "$SUBMODULE_DIR/encrypt/config"
    make_new_folder "$SUBMODULE_DIR/encrypt/archive"
    touch "$SUBMODULE_DIR/encrypt/archive/.gitkeep"
    git -C "$SUBMODULE_DIR" add encrypt
    # Commit and Push
    git -C "$SUBMODULE_DIR" commit -m "feat: initial commit"
    git -C "$SUBMODULE_DIR" branch -M "$BRANCH"
    git -C "$SUBMODULE_DIR" remote add origin "$REMOTE_URL"
    git -C "$SUBMODULE_DIR" push -u origin "$BRANCH"
    # Remove newly created repository to make room for submodule
    rm -rf "$PWD/${SUBMODULE_DIR:?}"
    # TODO: ensure that this new line works, see what can be done to add the submodule through yadm
    git submodule add "$REMOTE_URL" "$SUBMODULE_DIR"
    git config -f ".git/modules/$SUBMODULE_DIR/config" core.worktree "$PWD"
    "$SCRIPT_DIR/aliased_yadm.sh" "$SUBMODULE_DIR" init -f -w "$PWD"
    "$SCRIPT_DIR/aliased_yadm.sh" "$SUBMODULE_DIR" status
}

sudo "$SCRIPT_DIR/install_package.sh" "jq"
sudo "$SCRIPT_DIR/install_gh_cli.sh"

if ! gh auth status > /dev/null; then
    if ! gh auth login; then
        exit 1
    fi
fi

get_submodule_name "$@"
make_new_folder "$SUBMODULE_DIR"
initialize_submodule_repo
