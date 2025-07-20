#!/usr/bin/env bash

printf "\n-----Running %s-----\n" "$(basename "$0")"

SUBMODULE_NAME=""
SUBMODULE_DIR=".secrets" # Default value, can be overridden by --dir flag
MODE=""
ALLOWED_MODES=("local" "testing" "production")
PARENT_REPOSITORY_REMOTE=$(git config --get remote.origin.url)
SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

# Helper function to check if a value is in an array
contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Creates a new secrets repository as a git submodule and sets up chezmoi for project-local dotfile management.

Options:
  --mode <mode>         Set the operational mode. If not provided, chezmoi will prompt on first run.
                        Allowed modes: local, testing, production.
  --name <name>         The name for the new secrets git repository.
                        If not provided, you will be prompted.
  --dir <dir>           The local directory name for the submodule. Defaults to ".secrets".
  -h, --help            Display this help message and exit.
EOF
    exit 0
}

prompt_for_configuration() {
    # Check if parent git repository has been initialized
    if [ ! -e "./.git" ]; then
        echo "Error: Parent Git Repository Not Initialized. Must be run from project root." >&2
        exit 1
    fi

    # Validate the mode if it was passed as an argument
    if [ -n "$MODE" ]; then
        if ! contains_element "$MODE" "${ALLOWED_MODES[@]}"; then
            echo "Error: Invalid mode '$MODE'. Allowed modes are: ${ALLOWED_MODES[*]}" >&2
            exit 1
        fi
        echo "Mode set to '$MODE' from argument."
    fi

    # If submodule name was not provided via arguments, enter interactive setup.
    if [ -z "$SUBMODULE_NAME" ]; then
        echo "Entering interactive setup for secrets repository..."
        local default_submodule_name
        default_submodule_name="$(basename -s ".git" "$PARENT_REPOSITORY_REMOTE")-dotfiles"

        read -er -p $'\nPlease provide a name for the secrets git repository: ' -i "$default_submodule_name" SUBMODULE_NAME
        read -er -p $'\nPlease provide the name for the directory this new repository will be created within: ' -i "$SUBMODULE_DIR" SUBMODULE_DIR
    else
        echo "Using provided arguments for secrets repository:"
        echo "  Repository Name: $SUBMODULE_NAME"
        echo "  Directory:       $SUBMODULE_DIR"
    fi

    if [ -z "$SUBMODULE_NAME" ]; then
        echo "Error: Submodule name cannot be empty." >&2
        exit 1
    fi

    # Pre-flight check: Ensure the GitHub repository doesn't already exist.
    echo "--> Checking if GitHub repository '${SUBMODULE_NAME}' already exists..."
    if gh repo view "$SUBMODULE_NAME" >/dev/null 2>&1; then
        echo "Error: A GitHub repository named '${SUBMODULE_NAME}' already exists on your account." >&2
        echo "Please choose a different name or delete the existing repository." >&2
        exit 1
    fi
    echo "--> Repository name is available."
}

make_new_folder() {
    local dir_name="$1"
    # The bootstrap script already performs a pre-flight check to ensure this directory
    # does not exist, so we can proceed with creating it. The original `rm -rf`
    # has been removed to prevent accidental data loss.
    echo "--> Creating directory '$dir_name'..."
    if ! mkdir "$dir_name"; then
        echo "Error: Failed to create directory '$dir_name'." >&2
        exit 1
    fi
    echo "--> Directory '$dir_name' created."
}

initialize_submodule_repo() {
    # Prompt for git default branch with default parsed from git config
    local BRANCH
    read -er -p $'\nProvide a default branch name for the new repository: ' -i "$(git config --get init.defaultBranch || echo "main")" BRANCH
    if [ -z "$BRANCH" ]; then
        echo "Error: Branch name cannot be empty." >&2
        exit 1
    fi

    echo "--> Creating private GitHub repository '$SUBMODULE_NAME'..."
    gh repo create "$SUBMODULE_NAME" --private

    local REMOTE_URL
    REMOTE_URL=$(gh repo view "$SUBMODULE_NAME" --json "sshUrl" --jq ".sshUrl")
    if [ -z "$REMOTE_URL" ]; then
        echo "Error: Failed to get SSH URL for GitHub repository '$SUBMODULE_NAME'." >&2
        exit 1
    fi
    echo "--> Successfully created repository. SSH URL: $REMOTE_URL"

    echo "--> Initializing local repository in '$SUBMODULE_DIR'..."
    # Use pushd to safely work inside the new directory and popd to return.
    pushd "$SUBMODULE_DIR" || exit 1

    # Initialize git repo, create and commit initial files.
    git init -b "$BRANCH"

    # Create a .chezmoiignore file to prevent certain files from being managed by chezmoi.
    # This prevents the submodule's README from overwriting the parent repo's README.
    echo "README.md" > ".chezmoiignore"
    git add ".chezmoiignore"

    # Create a dot_env file for chezmoi. It will be populated if a mode is set.
    if [ -n "$MODE" ]; then
        echo "MODE=${MODE}" > "dot_env"
        echo "MODE=${MODE}" > "dot_env_${MODE}"
        git add "dot_env_${MODE}"
    else
        touch "dot_env"
    fi
    git add dot_env

    # Create a .gitignore template to be managed by chezmoi.
    # This will automatically populate the parent .gitignore with all files
    # managed by this chezmoi instance, plus the state file.
    # We use a template so that as new files are added with 'chezmoi add',
    # they are automatically added to the .gitignore on the next 'chezmoi apply'.
    cat << 'EOF' > "dot_gitignore.tmpl" # This creates .gitignore in the project root
# This file is managed by chezmoi from dot_gitignore.tmpl
# in the secrets repo. Do not edit it directly.

# Ignore the chezmoi state file.
.chezmoi/chezmoistate.boltdb

# Ignore all other files managed by this chezmoi instance.
{{ $managed := output "chezmoi" "--config" "./.chezmoi/.chezmoi.toml" "managed" | trim -}}
{{- range $line := split "\n" $managed -}}
{{-   if and $line (ne $line ".gitignore") -}}
{{ $line }}
{{-   end -}}
{{- end }}
EOF
    git add "dot_gitignore.tmpl"

    echo "# $SUBMODULE_NAME" > "README.md"
    git add README.md

    git commit -m "feat: initial commit"
    git remote add origin "$REMOTE_URL"
    git push -u origin "$BRANCH"

    popd || exit 1
    echo "--> Initial repository pushed to remote."

    # Remove the temporary directory and add the repo as a proper submodule.
    echo "--> Removing temporary directory and adding as submodule..."
    rm -rf "$SUBMODULE_DIR"
    git submodule add "$REMOTE_URL" "$SUBMODULE_DIR"
    echo "--> Submodule '$SUBMODULE_DIR' added."

    echo "--> Generating chezmoi config in .chezmoi/ ..."
    mkdir -p ".chezmoi"

    local mode_line
    if [ -n "$MODE" ]; then
        mode_line="mode = \"${MODE}\" # Set from bootstrap argument"
    else
        local choices_list
        choices_list=$(printf "\"%s\" " "${ALLOWED_MODES[@]}")
        choices_list="${choices_list% }" # Remove trailing space
        local default_choice="${ALLOWED_MODES[0]}"

        # Wrap the template in quotes to make it a valid TOML string. chezmoi evaluates templates in data values.
        # This will prompt the user to select a mode on the first 'chezmoi apply' if one wasn't provided via --mode.
        # Use single quotes for the TOML value to avoid issues with nested double quotes inside the template function.
        mode_line="mode = '{{ promptMultichoiceOnce \"chezmoi.data.mode\" \"Select operational mode\" (list ${choices_list}) \"${default_choice}\" }}'"
    fi

    cat << EOF > ".chezmoi/.chezmoi.toml"
# .chezmoi/.chezmoi.toml
# Local project configuration for chezmoi.

# The source directory is the secrets submodule.
sourceDir = "../${SUBMODULE_DIR}"

# The destination directory is the project root.
destDir = ".."

[data]
# This value determines the operational mode for this project's configuration.
# It will prompt on the first 'chezmoi apply' if a mode was not set during setup.
${mode_line}
EOF
    echo "--> .chezmoi/.chezmoi.toml created."
}

print_success_message() {
    cat <<EOF

✅ Project setup complete!

The secrets submodule has been created in '${SUBMODULE_DIR}' and '.chezmoi/.chezmoi.toml' is configured.

A 'dot_gitignore.tmpl' file has been created in your new secrets repository.
This template will automatically generate a '.gitignore' file in your project root
that lists all files managed by chezmoi.

Run 'chezmoi --config ./.chezmoi/.chezmoi.toml apply' to generate the initial '.gitignore'.
Each time you run 'apply', the .gitignore will be updated with any newly added files.

To manage this project's dotfiles, you must use the local configuration file for all commands.
Example:
  chezmoi --config ./.chezmoi/.chezmoi.toml apply
  chezmoi --config ./.chezmoi/.chezmoi.toml add ~/.config/some/app/config.file

For convenience, consider creating a temporary shell alias for your current session:
  alias czm='chezmoi --config ./.chezmoi/.chezmoi.toml'
  # Now you can run: czm apply
EOF
}


# --- Main Execution ---

# Argument parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                MODE="$2"
                shift 2
            else
                echo "Error: --mode requires a value." >&2
                usage
            fi
            ;;
        --name)
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                SUBMODULE_NAME="$2"
                shift 2
            else
                echo "Error: --name requires a value." >&2
                usage
            fi
            ;;
        --dir)
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                SUBMODULE_DIR="$2"
                shift 2
            else
                echo "Error: --dir requires a value." >&2
                usage
            fi
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage
            exit 1
    esac
done

sudo "$SCRIPT_DIR/install_package.sh" "jq"
sudo "$SCRIPT_DIR/install_gh_cli.sh"

if ! gh auth status > /dev/null; then
    if ! gh auth login; then
        exit 1
    fi
fi

prompt_for_configuration
make_new_folder "$SUBMODULE_DIR"
initialize_submodule_repo
print_success_message