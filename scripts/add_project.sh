#!/usr/bin/env bash

printf "\n-----Running %s-----\n" "$(basename "$0")"

SUBMODULE_NAME=""
SUBMODULE_DIR=".secrets" # Default value, can be overridden by --dir flag
MODE=""
ALLOWED_MODES=("local" "testing" "production")
PARENT_REPOSITORY_REMOTE=$(git config --get remote.origin.url)
ENABLE_ENCRYPTION=""
GPG_KEY_ID=""

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
  --encrypt             Enable GPG encryption for chezmoi-managed files.
  --gpg-key <key_id>    Use an existing GPG key ID. If not provided with --encrypt, a new key will be generated.
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

    # Prompt for encryption setup if not provided via arguments
    if [ -z "$ENABLE_ENCRYPTION" ]; then
        echo ""
        read -r -p "Enable GPG encryption for chezmoi-managed files? (y/N): " encrypt_response
        if [[ "$encrypt_response" =~ ^[Yy]$ ]]; then
            ENABLE_ENCRYPTION="yes"
        else
            ENABLE_ENCRYPTION="no"
        fi
    fi

    # If encryption is enabled, handle GPG key setup
    if [ "$ENABLE_ENCRYPTION" = "yes" ]; then
        if [ -z "$GPG_KEY_ID" ]; then
            echo ""
            echo "GPG encryption is enabled. You can use an existing GPG key or generate a new one."
            read -r -p "Use an existing GPG key? (y/N): " use_existing_key

            if [[ "$use_existing_key" =~ ^[Yy]$ ]]; then
                # List available GPG keys
                echo ""
                echo "Available GPG keys:"
                gpg --list-secret-keys --keyid-format LONG
                echo ""
                read -r -p "Enter the GPG key ID to use: " GPG_KEY_ID

                if [ -z "$GPG_KEY_ID" ]; then
                    echo "Error: GPG key ID cannot be empty." >&2
                    exit 1
                fi

                # Verify the key exists
                if ! gpg --list-secret-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
                    echo "Error: GPG key '$GPG_KEY_ID' not found." >&2
                    exit 1
                fi
            else
                echo ""
                echo "A new GPG key will be generated with the following settings:"
                echo "  - Key type: RSA"
                echo "  - Key length: 4096 bits"
                echo "  - Expiration: No expiration"
                echo "  - Name format: <project-name>-chezmoi"
                echo ""
                # GPG key will be generated in setup_gpg_encryption function
            fi
        # Verify the provided key exists
        elif ! gpg --list-secret-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
            echo "Error: Provided GPG key '$GPG_KEY_ID' not found." >&2
            exit 1
        fi

        # Setup GPG encryption now that we have all the configuration
        setup_gpg_encryption
    fi
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

setup_gpg_encryption() {
    # Generate a new GPG key if one wasn't provided
    if [ -z "$GPG_KEY_ID" ]; then
        local key_name="${SUBMODULE_NAME}-chezmoi"
        local key_email="${SUBMODULE_NAME}-chezmoi@localhost"

        # Check if a key with this email already exists
        local existing_key_count
        existing_key_count=$(gpg --list-secret-keys --with-colons "$key_email" 2>/dev/null | grep -c "^sec:")

        if [ "$existing_key_count" -gt 0 ]; then
            echo "A GPG key with email '$key_email' already exists."

            if [ "$existing_key_count" -eq 1 ]; then
                # Exactly one key found - offer to reuse it
                local existing_key_id
                existing_key_id=$(gpg --list-secret-keys --with-colons "$key_email" | awk -F: '/^sec:/ {print $5; exit}')

                echo "Found existing key: $existing_key_id"
                read -r -p "Reuse this key for chezmoi encryption? (Y/n): " reuse_key

                if [[ ! "$reuse_key" =~ ^[Nn]$ ]]; then
                    GPG_KEY_ID="$existing_key_id"
                    echo "--> Using existing GPG key: $GPG_KEY_ID"
                    return 0
                fi
            else
                # Multiple keys found
                echo "Multiple keys found with this email. Please choose a unique email or select an existing key."
            fi

            # User chose not to reuse or multiple keys exist - prompt for unique email
            echo ""
            read -er -p "Enter a unique email for the new GPG key: " -i "${SUBMODULE_NAME}-chezmoi-$(date +%s)@localhost" key_email

            if [ -z "$key_email" ]; then
                echo "Error: Email cannot be empty." >&2
                exit 1
            fi

            # Re-check the new email
            existing_key_count=$(gpg --list-secret-keys --with-colons "$key_email" 2>/dev/null | grep -c "^sec:")
            if [ "$existing_key_count" -gt 0 ]; then
                echo "Error: Email '$key_email' is still not unique. Please delete existing keys or choose a different email." >&2
                exit 1
            fi
        fi

        echo "--> Generating new GPG key for chezmoi encryption..."
        echo "    Name: $key_name"
        echo "    Email: $key_email"

        # Create GPG key generation batch file with predefined settings
        local gpg_batch_file
        gpg_batch_file=$(mktemp)
        cat > "$gpg_batch_file" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $key_name
Name-Email: $key_email
Expire-Date: 0
%commit
EOF

        # Generate the key
        if ! gpg --batch --generate-key "$gpg_batch_file" 2>&1; then
            echo "Error: Failed to generate GPG key." >&2
            rm -f "$gpg_batch_file"
            exit 1
        fi

        rm -f "$gpg_batch_file"

        # Get the key ID of the newly generated key using colon-delimited output
        # Field 5 contains the key ID in lines starting with 'sec:'
        GPG_KEY_ID=$(gpg --list-secret-keys --with-colons "$key_email" | awk -F: '/^sec:/ {print $5; exit}')

        if [ -z "$GPG_KEY_ID" ]; then
            echo "Error: Failed to retrieve generated GPG key ID." >&2
            exit 1
        fi

        echo "--> GPG key generated successfully: $GPG_KEY_ID"
    else
        echo "--> Using existing GPG key: $GPG_KEY_ID"
    fi
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

    local mode_line
    if [ -n "$MODE" ]; then
        mode_line="mode = \"${MODE}\" # Set from bootstrap argument"
    else
        local choices_list
        choices_list=$(printf "\"%s\" " "${ALLOWED_MODES[@]}")
        choices_list="${choices_list% }" # Remove trailing space
        local default_choice="${ALLOWED_MODES[0]}"

        # The promptChoiceOnce function stores its result in the state file.
        # Wrap the template in quotes to make it a valid TOML string. chezmoi evaluates templates in data values.
        # This will prompt the user to select a mode on the first 'chezmoi apply' if one wasn't provided via --mode.
        mode_line="mode={{ promptChoiceOnce . \"project.mode\" \"Select operational mode\" (list ${choices_list}) \"${default_choice}\" | quote }}"
    fi

    make_new_folder "dot_chezmoi"

    # Build encryption configuration if enabled
    local encryption_config=""
    if [ "$ENABLE_ENCRYPTION" = "yes" ]; then
        encryption_config="# GPG encryption is enabled for this project
encryption = \"gpg\"

[gpg]
# The GPG key ID used for encrypting chezmoi-managed files
recipient = \"${GPG_KEY_ID}\"

"
    fi

    cat << EOF > ".chezmoi.toml.tmpl"
# .chezmoi.toml
# Local project configuration for chezmoi.

# The source directory is the secrets submodule.
sourceDir = "./${SUBMODULE_DIR}"

# The destination directory is the project root.
destDir = "."

${encryption_config}
[data]
# This value determines the operational mode for this project's configuration.
# It will prompt on the first 'chezmoi apply' if a mode was not set during setup.
${mode_line}
EOF
    echo "--> .chezmoi.toml.tmpl created."
    git add ".chezmoi.toml.tmpl"

    # Create a .chezmoiignore file to prevent certain files from being managed by chezmoi.
    # This prevents the submodule's README from overwriting the parent repo's README.
    echo "README.md" > ".chezmoiignore"
    git add ".chezmoiignore"

    CHEZMOI_VERSION=$(chezmoi --version)
    # Create a .chezmoiversion file to limit the minimium version of chezmoi that can be used on this repo
    echo "${CHEZMOI_VERSION#v}" > ".chezmoiversion"
    git add ".chezmoiversion"

    # Create a .env template.
    echo "--> Creating .env template to trigger mode prompt..."
    echo 'MODE={{ .mode }}' > "dot_env.tmpl"
    git add "dot_env.tmpl"

    # Create a .gitignore template that won't overwrite an existing project .gitignore.
    echo "--> Creating .gitignore template..."
    local project_root_gitignore="../.gitignore"

    # This template will generate the .gitignore in the project root.
    cat << 'EOF' > "dot_gitignore.tmpl"
# This file is managed by chezmoi from dot_gitignore.tmpl
# in the secrets repo. Do not edit it directly.
EOF

    # If a .gitignore exists in the project root, copy its contents into the template.
    if [ -f "$project_root_gitignore" ]; then
        echo "--> Found existing .gitignore. Preserving its content in the template."
        {
            echo
            echo "# --- Start of content from original .gitignore ---"
            cat "$project_root_gitignore"
            echo
            echo "# --- End of content from original .gitignore ---"
            echo
        } >> "dot_gitignore.tmpl"
    fi

    # Append the dynamic part that ignores chezmoi-managed files.
    # Using .chezmoi.destDir ensures the path to the config is always correct.
    cat << 'EOF' >> "dot_gitignore.tmpl"
# --- Start of chezmoi-managed entries ---

# Ignore the chezmoi state file.
chezmoistate.boltdb

# Ignore all other files managed by this chezmoi instance.
{{ $configPath := joinPath (.chezmoi.destDir | toString) ".chezmoi" ".chezmoi.toml" -}}
{{ $managed := output "chezmoi" "--config" $configPath "managed" | trim -}}
{{- range $line := split "\n" $managed -}}
{{-   if and $line (ne $line ".gitignore") -}}
{{ $line }}
{{-   end -}}
{{- end }}
# --- End of chezmoi-managed entries ---
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
}

print_success_message() {
    local encryption_msg=""
    if [ "$ENABLE_ENCRYPTION" = "yes" ]; then
        encryption_msg="
🔐 GPG Encryption is enabled!
   GPG Key ID: ${GPG_KEY_ID}

   To add encrypted files, use the encrypted_ prefix:
     chezmoi --config ./.chezmoi.toml add --encrypt file.txt
   This will create 'encrypted_file.txt.age' in your secrets repository.

   For CI/CD pipelines, you'll need to export and configure the GPG key.
   See the README for detailed instructions on:
     - Exporting the private key: gpg --export-secret-keys --armor ${GPG_KEY_ID}
     - Configuring CI secrets (GPG_PRIVATE_KEY, GPG_KEY_ID)
     - Importing keys in CI environments
"
    fi

    cat <<EOF

✅ Project setup complete!

The secrets submodule has been created in '${SUBMODULE_DIR}' and '.chezmoi.toml' is configured.
${encryption_msg}
A 'dot_gitignore.tmpl' file has been created in your new secrets repository.
This template will automatically generate a '.gitignore' file in your project root
that lists all files managed by chezmoi.

Run 'chezmoi --config ./.chezmoi.toml apply' to generate the initial '.gitignore'.
Each time you run 'apply', the .gitignore will be updated with any newly added files.

To manage this project's dotfiles, you must use the local configuration file for all commands.
Example:
  chezmoi --config ./.chezmoi.toml apply
  chezmoi --config ./.chezmoi.toml add ~/.config/some/app/config.file

For convenience, consider creating a temporary shell alias for your current session:
  alias czm='chezmoi --config ./.chezmoi.toml'
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
        --encrypt)
            ENABLE_ENCRYPTION="yes"
            shift
            ;;
        --gpg-key)
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                GPG_KEY_ID="$2"
                ENABLE_ENCRYPTION="yes"
                shift 2
            else
                echo "Error: --gpg-key requires a value." >&2
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

prompt_for_configuration
make_new_folder "$SUBMODULE_DIR"
initialize_submodule_repo
print_success_message