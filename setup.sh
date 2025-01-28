#!/bin/bash

# Define the source directory where the new config files are located
SOURCE_DIR="$HOME/dotfiles"

# Define an associative array with the files to link.
# The keys are the source files in the SOURCE_DIR.
# The values are the names of the target files in the home directory.
declare -A files_to_link=(
    ["nvim/"]=".config/nvim/lua/custom"
    [".config/skhd"]=".config/skhd"
    [".config/aerospace"]=".config/aerospace"
    [".tmux.conf"]=".tmux.conf"
    [".zshrc"]=".zshrc"
    [".p10k.zsh"]=".p10k.zsh"
    [".wezterm.lua"]=".wezterm.lua"
    [".gitconfig"]=".gitconfig"
)

# Iterate through the associative array
for source_file in "${!files_to_link[@]}"
do
    target_file="${files_to_link[$source_file]}"

    # Replace '_' with '.' in the source file name
    # source_file=${source_file//_/.}

    # Full path for source and target
    source_path="${SOURCE_DIR}/${source_file}"
    target_path="$HOME/${target_file}"

    # Remove the existing file in the home directory (if it exists)
    if [ -f "$target_path" ] || [ -L "$target_path" ]; then
        rm -f "$target_path"
        echo "Removed existing file: $target_path"
    fi

    # Create a symbolic link
    ln -s "$source_path" "$target_path"
    echo "Created symlink:  $source_path -> $target_path"
done

echo "All done!"
