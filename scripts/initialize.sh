# Make sure to initialize 
git submodule init

# Symlink the downloaded yadm script to the users path
YADM_SYMLINK_DESTINATION="/home/$USER/.local/bin/yadm"
if [ -L "$YADM_SYMLINK_DESTINATION" ]; then
    # File is already symlinked no action needed
    echo "File already symlinked at $YADM_SYMLINK_DESTINATION"
elif [ -e "$YADM_SYMLINK_DESTINATION" ]; then
    # File exists already and is not a symlink
    echo "Non-symlinked located at $YADM_SYMLINK_DESTINATION"
    exit 1
else
    # file does not exist at all 
    ln -s "$PWD/yadm/yadm" "$YADM_SYMLINK_DESTINATION"
fi

# Once YADM is initialized run submodule initialization for parent repository
if [ ! -e "./../.git" ]; then
    echo "Parent Git Repository Not Initialized"
    exit 1
fi

git submodule update --remote yadm

PARENT_REPOSITORY_REMOTE=`git -C .. config --get remote.origin.url`
echo $PARENT_REPOSITORY_REMOTE
SUBDIR=`basename -s ".git" $PARENT_REPOSITORY_REMOTE`