local M = {}
local c = vim.cmd

-- different REPLs require different delimiters etc to work properly
-- this config dir holds all the configurations
-- blocks are blocks of lines, e.g. send via range selection or via jupytext-like cells

local config = {
    nu = {
        block_delimiter_start = "",
        block_delimiter_end = "",
        newline_delimiter = "",
    },
    python = {
        block_delimiter_start = "%cpaste -q\n",
        block_delimiter_end = "--\n",
        newline_delimiter = "",
    },
}
M.path = os.getenv("HOME") .. "/kitty.nvim/lua/kitty/"
-- this is a dev tool which helps reloading
-- the pluggin files
function M.reload()
    for k in pairs(package.loaded) do
        if k:match("kitty") then
            print("reloading " .. k)
            package.loaded[k] = nil
        end
    end
end

local kitty_listen_on = "unix:/tmp/mykitty"
local cell_delimiter = '# %%'
local cell_delimiter_regex = '# \\%\\%'

local imports = [[
from pathlib import Path
import json
import os
import pandas as pd

json_file = "/tmp/tmp.json"
csv_file = "/tmp/tmp.csv"
bin_file = "/tmp/tmp.bin"
]]

local hexyl_cmd = [[
with Path(bin_file).open("wb") as a:
    a.write(r)
! hexyl {bin_file}
]]

local nvim_cmd = [[
with Path(json_file).open("w") as a:
    a.write(json.dumps(r))

!nvim {json_file}
]]

local fx_cmd = [[
with Path(json_file).open("w") as a:
    a.write(json.dumps(r))
! fx {json_file}
]]

local vd_cmd = [[
r.to_csv(csv_file)
! vd {csv_file}
]]

function M.setup(config)
    c([[
    highlight KittyCellDelimiterColor guifg=#191920 guibg=#1e1f28
    sign define KittyCellDelimiters linehl=KittyCellDelimiterColor text=>
    ]])
    M.init_user_commands()
end

function M.highlight_cell_delimiter()
    c("sign unplace * group=KittyCellDelimiters buffer=" .. vim.fn.bufnr())
    local lines = vim.fn.getline(0, '$')
    for line_number, line in pairs(lines) do
        if line:find(cell_delimiter) then
            c(
                "sign place 1 line=" ..
                line_number ..
                " group=KittyCellDelimiters name=KittyCellDelimiters buffer=" ..
                vim.fn.bufnr()
             )
        end
    end

end



function M.open(program)
    -- note: we're doing zsh -c to have the env be populated correctly
    M.id = vim.fn.system("kitty @ --to unix:/tmp/mykitty launch  --type=os-window zsh -c '" .. program.. "'" ):gsub("\n+[^\n]*$", "")
end
function M.send_cell()
    local opts = {}
    opts.line1 = vim.fn.search(cell_delimiter, 'bcnW')
    opts.line2 = vim.fn.search(cell_delimiter, 'nW')

    -- line after delimiter or top of file
    opts.line1 = opts.line1 and opts.line1 + 1 or  1
    -- line before delimiter or bottom of file
    opts.line2 = opts.line2 and opts.line2 - 1 or vim.fn.line("$")

    if opts.line1 <= opts.line2 then
        M.send_range(opts)
    end
end

function M.send_range(opts)
    local startline = opts.line1
    local endline = opts.line2
    -- save registers for restore
    local rv = vim.fn.getreg('"')
    local rt = vim.fn.getregtype('"')
    c( startline .. ',' ..  endline .. "yank" )
    local payload = vim.fn.getreg("@\"")
    -- restore
    M.send_block(payload)
    vim.fn.setreg('"', rv, rt)
end

function M.send_block(payload)
    local prefix = config[vim.bo.filetype].block_delimiter_start
    local suffix = config[vim.bo.filetype].block_delimiter_end

    if prefix then
        M.send(prefix)
    end
    M.send(payload)
    if suffix then
        M.send(suffix)
    end
end
function M.send_current_line()
    local line = vim.fn.line(".")
    local payload = vim.fn.getline(line)
    M.send(payload .. "\n")
end

function M.send_current_word()
    c("normal! yiw")
    M.send(vim.fn.getreg("@\"") .. "\n")
end

function M.send_file()
    local filename = vim.fn.expand("%:p")
    local payload = ""
    local lines = vim.fn.readfile(filename)
    for _, line in ipairs(lines) do
        payload = payload .. line .. "\n"
    end
    M.send_block(payload)
end

function M.send(text)
   local  to_flag = " --to " .. vim.fn.shellescape(kitty_listen_on)
   local cmd = "kitty @" .. to_flag .. " send-text --match id:" .. vim.fn.shellescape(M.id) .. " --stdin"
   vim.fn.system(cmd, text)
   vim.fn.system(cmd, "\r")
end

function M._store_var()
    c("normal! yiw")
    M.send("r = " .. vim.fn.getreg("@\"") .. "\n")
end

function M.do_imports()
    M.send(imports .. "\n")
end

function M.fx_current_word()
    M._store_var()
    M.send(fx_cmd .. "\n")
end

function M.hexyl_current_word()
    M._store_var()
    M.send(hexyl_cmd .. "\n")
end

function M.nvim_current_word()
    M._store_var()
    M.send(nvim_cmd .. "\n")
end

function M.vd_current_word()
    M._store_var()
    M.send(vd_cmd .. "\n")
end

M.get_selection = function()
    vim.cmd('normal! y')
    return vim.fn.getreg('"')
end
M.send_selection = function()
    M.send(M.get_selection())
end

local function _C(name, cb, desc, range)
    vim.api.nvim_create_user_command("Kitty" .. name, cb, {
        nargs = "*",
        desc = desc,
        range = range or 1,
    })
end

function M.init_user_commands()
    _C("IPy", function() M.open("ipython") end, "Open IPython in Kitty")
    _C("Nu", function() M.open("nu") end, "Open Nu in Kitty")
    _C("Zsh", function() M.open("zsh") end, "Open zsh in Kitty")
    _C("Hs", function() M.open("lua") end, "Open hammerspoon in Kitty")
    _C("SendCell", M.send_cell, "Send Cell in Kitty")
    _C("SendCurrentLine", M.send_current_line, "Send Cell in Kitty")
    _C("SendWord", M.send_current_word, "Send Cell in Kitty")
    _C("SendLines", M.send_range, "Send Cell in Kitty", "%")
    _C("SendFile", M.send_file, "Send File in Kitty")
    _C("SendSelection", M.send_selection, "Send selection in Kitty")
    _C("Reload", M.reload, "Reload Kitty (DevTool)")
end

return M
