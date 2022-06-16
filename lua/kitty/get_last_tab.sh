#! /bin/zsh
kitty @ ls | 
jq '.[] | 
.tabs[] |
select(.is_focused==true) |
.active_window_history[]' |
head -n 2 |
tail -n 1 | 
tr -d '\n'
