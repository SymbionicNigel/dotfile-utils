#!/usr/bin/env bash

printf "\n-----Running %s-----\n" "$(basename "$0")"

SUBMODULE_DIR=$1
shift

YADM_DIR="$PWD/$SUBMODULE_DIR" # TODO: determine if this should be used across all repos and moved to the dotfile-utils repo, or can we use both
DATA_DIR="$YADM_DIR/data"
REPO_DIR="$PWD/.git/modules/$SUBMODULE_DIR"




run_yadm() {
    # yadm --yadm-data "$DATA_DIR" --yadm-dir "$YADM_DIR" --yadm-repo "$REPO_DIR" init -f -w "$DATA_DIR"
    yadm --yadm-data "$DATA_DIR" --yadm-dir "$YADM_DIR" --yadm-repo "$REPO_DIR" "$@"
}

run_yadm "$@"