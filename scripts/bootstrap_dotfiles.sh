
# TODO: check if there is a script located at scripts/bootstrap.sh
# TODO: Pass in a subdirectory to bootstrap
    # This will fix the "/home/nigel-krajcer/bin/yadm: line 1905: cd: ../../../.secrets: No such file or directory" error
# TODO: need to make sure that setting BASE_DIR is correct.

DATA_DIR="$(pwd)/.secrets"
REPO_DIR="$(pwd)/.git/modules/.secrets"
# This is the config for use across all of my 
YADM_DIR="$(pwd)/dotfiles/config"

run_yadm() {
    yadm --yadm-data "$DATA_DIR" --yadm-dir "$YADM_DIR" --yadm-repo "$REPO_DIR" init -f -w "$DATA_DIR"
}

run_yadm