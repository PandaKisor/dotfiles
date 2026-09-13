#source /usr/share/cachyos-fish-config/cachyos-config.fish


function fish_greeting
end

if status is-interactive; and command -q fastfetch
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
