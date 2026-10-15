# Search file contents from the current directory and open a selected match.
function __gnesha_search_contents
    set -l query
    read -P "Search text: " query
    or return
    test -n "$query"; or return

    set -l match (rg --line-number --no-heading --color=never --fixed-strings --smart-case -- "$query" . \
        | fzf --delimiter : \
            --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
            --preview-window 'right,60%,border-left')
    or return

    set -l fields (string split -m 2 : -- "$match")
    if test (count $fields) -ge 2
        nvim "+$fields[2]" -- "$fields[1]"
    end
end

# Ctrl-G starts interactive ripgrep content search.
bind \cg __gnesha_search_contents
