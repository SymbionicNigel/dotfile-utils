#!/usr/bin/env bash
set -euo pipefail

# Configuration
CHEZMOI_CONFIG=".chezmoi.toml"
SOURCE_DIR=""
ENCRYPT=false

usage() {
    cat << EOF
Usage: $0 [OPTIONS] <file-path>

Add files to chezmoi-managed repository from the project directory.

This script solves the limitation where chezmoi won't add files from the
directory it manages by copying them to the chezmoi source directory first.

OPTIONS:
    --encrypt       Add 'encrypted_' prefix to enable GPG encryption
                    (requires GPG to be configured in .chezmoi.toml)
    -h, --help      Show this help message

ARGUMENTS:
    file-path       Relative or absolute path to the file to add

EXAMPLES:
    $0 .env
    $0 --encrypt .env
    $0 -h|--help

DESCRIPTION:
    This script:
    1. Copies the file to the chezmoi source directory with proper naming
    2. Converts dotfile names (e.g., .env -> dot_env)
    3. Adds 'encrypted_' prefix if --encrypt is used
    4. Applies changes to deploy the file back to the project
    5. Stages the file in the chezmoi-managed git repository

    Files with the 'encrypted_' prefix will be automatically encrypted
    by chezmoi using GPG when applied.

    The script must be run from the project root directory.
EOF
    exit 0
}

validate_environment() {
    if [[ ! -f "$CHEZMOI_CONFIG" ]]; then
        echo "Error: $CHEZMOI_CONFIG not found in current directory"
        echo "Please run this script from the project root"
        exit 1
    fi

    # Read sourceDir from chezmoi
    SOURCE_DIR=$(chezmoi --config "$CHEZMOI_CONFIG" source-path)

    if [[ -z "$SOURCE_DIR" ]]; then
        echo "Error: Could not determine source directory from chezmoi"
        exit 1
    fi

    if [[ ! -d "$SOURCE_DIR" ]]; then
        echo "Error: Source directory $SOURCE_DIR not found"
        exit 1
    fi

    # Check if encryption is configured when --encrypt flag is used
    if [[ "$ENCRYPT" = true ]]; then
        local encryption_type
        encryption_type=$(chezmoi --config "$CHEZMOI_CONFIG" dump-config --format json | jq -r '.encryption // empty' 2>/dev/null)

        if [[ -z "$encryption_type" ]]; then
            echo "Error: --encrypt flag requires GPG encryption to be configured in $CHEZMOI_CONFIG"
            echo "Run bootstrap with --encrypt flag to set up encryption, or see README for manual setup"
            exit 1
        fi
    fi
}

parse_arguments() {
    # Check for help flag first
    if [[ $# -ge 1 ]] && { [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]]; }; then
        usage
    fi

    if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
        echo "Error: Invalid number of arguments"
        usage
    fi

    # Parse arguments
    if [[ "$1" = "--encrypt" ]]; then
        ENCRYPT=true
        if [[ $# -ne 2 ]]; then
            echo "Error: --encrypt flag requires a file path"
            usage
        fi
        INPUT_PATH="$2"
    else
        INPUT_PATH="$1"
    fi
}

resolve_file_path() {
    local input_path="$1"
    
    # Convert to absolute path
    if [[ "$input_path" = /* ]]; then
        ABSOLUTE_PATH="$input_path"
    else
        ABSOLUTE_PATH="$(cd "$(dirname "$input_path")" && pwd)/$(basename "$input_path")"
    fi

    # Check if file exists
    if [[ ! -f "$ABSOLUTE_PATH" ]]; then
        echo "Error: File does not exist: $ABSOLUTE_PATH"
        exit 1
    fi

    # Get relative path from project root
    RELATIVE_PATH="${ABSOLUTE_PATH#"$(pwd)"/}"

    # If the path didn't change, the file is outside project root
    if [[ "$RELATIVE_PATH" = "$ABSOLUTE_PATH" ]]; then
        echo "Error: File must be within the project directory"
        echo "File: $ABSOLUTE_PATH"
        echo "Project root: $(pwd)"
        exit 1
    fi

    # Remove leading ./
    RELATIVE_PATH="${RELATIVE_PATH#./}"
}

convert_to_chezmoi_path() {
    # Split the path into components and convert each one
    IFS='/' read -ra PATH_PARTS <<< "$RELATIVE_PATH"
    CHEZMOI_PARTS=()

    for i in "${!PATH_PARTS[@]}"; do
        part="${PATH_PARTS[$i]}"
        if [[ -z "$part" ]]; then
            continue
        fi
        
        # For the last component (filename), add encrypted_ prefix if requested
        if [[ $i -eq $((${#PATH_PARTS[@]} - 1)) ]] && [[ "$ENCRYPT" = true ]]; then
            if [[ "$part" = .* ]]; then
                # .env -> encrypted_dot_env
                CHEZMOI_PARTS+=("encrypted_dot_${part#.}")
            else
                # secret.txt -> encrypted_secret.txt
                CHEZMOI_PARTS+=("encrypted_$part")
            fi
        # For all other components, convert dots normally
        elif [[ "$part" = .* ]]; then
            # .config -> dot_config
            CHEZMOI_PARTS+=("dot_${part#.}")
        else
            # No conversion needed for parts not starting with .
            CHEZMOI_PARTS+=("$part")
        fi
    done

    # Reconstruct the path
    CHEZMOI_PATH=$(IFS=/; echo "${CHEZMOI_PARTS[*]}")
    SOURCE_PATH="$SOURCE_DIR/$CHEZMOI_PATH"
}

copy_file() {
    # Create directory structure in .secrets
    SOURCE_DIR_PATH="$(dirname "$SOURCE_PATH")"
    mkdir -p "$SOURCE_DIR_PATH"

    # Check if file already exists in source
    if [[ -f "$SOURCE_PATH" ]]; then
        echo "Warning: File already exists in source: $SOURCE_PATH"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    # If encryption is enabled, encrypt with chezmoi
    if [[ "$ENCRYPT" = true ]]; then
        echo "Encrypting file..."
        if chezmoi --config "$CHEZMOI_CONFIG" encrypt "$ABSOLUTE_PATH" --output "$SOURCE_PATH"; then
            echo "File encrypted successfully"
        else
            echo "Error: Encryption failed"
            exit 1
        fi
    else
        # Copy file to source without encryption
        cp "$ABSOLUTE_PATH" "$SOURCE_PATH"
    fi

    echo "Successfully added file to chezmoi source"
    echo "  Source file: $RELATIVE_PATH"
    echo "  Chezmoi path: $SOURCE_PATH"
    echo ""
}

apply_changes() {
    echo "Applying changes..."
    if chezmoi --config "$CHEZMOI_CONFIG" apply "$RELATIVE_PATH"; then
        echo "Chezmoi changes applied successfully"
    else
        echo "Warning: Apply failed, but file was added to source"
    fi
}

stage_in_git() {
    echo "Staging file in .secrets repo..."
    if chezmoi --config "$CHEZMOI_CONFIG" git -- add "$CHEZMOI_PATH"; then
        echo "File staged with chezmoi"
        echo "Next steps: review, commit, and push!"
    else
        echo "Warning: Failed to stage file in git"
    fi
}

# Execute
parse_arguments "$@"
validate_environment
resolve_file_path "$INPUT_PATH"
convert_to_chezmoi_path
copy_file
apply_changes
stage_in_git