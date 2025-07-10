#!/usr/bin/env bash

DIRECTORY=".secrets"

# De-initialize the submodule
git submodule deinit -f "$DIRECTORY"

# Remove submodule entry from .gitmodules
git rm --cached "$DIRECTORY"

# Remove submodule from parent git config
git config --remove-section "submodule.$DIRECTORY"

# Remove the submodule directory
rm -rf "$DIRECTORY"

# Remove the submodule from .git/modules:
rm -rf ".git/modules/$DIRECTORY"

# TODO: remove section from .gitmodules