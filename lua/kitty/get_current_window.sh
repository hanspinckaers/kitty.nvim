#! /bin/zsh
kitty @ ls | jq '.[] | select(.is_focused==true) | .id'
