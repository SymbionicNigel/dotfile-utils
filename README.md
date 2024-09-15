# DotFiles

![Repository Structure](./media/structure.png)

## Basic Usage

### On Clone/Initialization

### Adding files to storage

### Encryption/GPG

### Adding another project as a submodule

## Choice of using YADM

When researching different methods of storing dotfiles securely and in a manner which makes tracking and applying updates to the desired repositories easy, there were three main options. GNU/Stow, a cli tool included on most UNIX machines, dotdrop, a python package, and yadm, a cli tool with a little more flexibility than stow. All of these options use git as a storage mechanism for the files which are to be symlinked into place.

The stow's limitation of only being able to use `$HOME` as the root of the directory its symlinked files will be mapped to is what removed it from contention. For the most part the other options are nearly identical, using git as a backend, allow for templating files, integrations with git-crypt and gpg, and use of git submodules. What made YADM the tool of choice was the lack of additional dependencies (python and Pypi packages), a simpler more streamlined templating feature, and a reliance on git command syntax as opposed to custom commands and more configuration files.
