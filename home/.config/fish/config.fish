#source /usr/share/cachyos-fish-config/cachyos-config.fish

# Override an older desktop session's editor when opening a new terminal.
set -gx EDITOR /usr/bin/nvim
set -gx VISUAL /usr/bin/nvim
set -gx SUDO_EDITOR /usr/bin/nvim


function fish_greeting
end

if status is-interactive; and command -q fastfetch
    # Apply Pywal colors to every newly opened terminal.
    if test -r ~/.cache/wal/sequences
        command cat ~/.cache/wal/sequences
    end

    if test -f ~/.config/fastfetch/config.jsonc
        fastfetch --config ~/.config/fastfetch/config.jsonc
    else
        fastfetch
    end
end

#overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
export PATH="$HOME/.local/bin:$PATH"
