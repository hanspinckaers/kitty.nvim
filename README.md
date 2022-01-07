# kitty.nvim
Slime-like REPL for Neovim in Lua

This is a very simple, single file plugin.

I might get more organized but right now the scope is only to be able 
to send either 

	- selected text
	- "# %%" formatted jupyter notebook cells
	- whole files
	- lines
	- current word

To the last recently focused kitty pane.

This is pretty much all I need - but PR's welcome

# requirements

```shell
brew install jq
```

Also you need this little bad boy in your kitty.conf

```
listen_on unix:/tmp/mykitty
```
# key mappings

You do you, but these are mine

```
nnoremap <space>k :lua require'kitty'.send_cell()<cr>
nnoremap <space>l :lua require'kitty'.send_current_line()<cr>
vnoremap <space>l :lua require'kitty'.send_selected_lines()<cr>
nnoremap <space>h :lua require'kitty'.send_current_word()<cr>
```
