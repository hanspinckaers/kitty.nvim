local M = {}
local c = vim.cmd

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

function M.repl_prefix()
    if vim.bo.filetype == "python" then
        return "%cpaste -q\n"
   end
end

function M.repl_suffix()
    if vim.bo.filetype == "python" then
        return "--\n"
    end
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
    M.id = vim.fn.system("kitty @ --to unix:/tmp/mykitty launch  --type=os-window " .. program):gsub("\n+[^\n]*$", "")
   print("id:", M.id)
end
function M.send_cell()
    local line_ini = vim.fn.search(cell_delimiter, 'bcnW')
    local line_end = vim.fn.search(cell_delimiter, 'nW')

    -- line after delimiter or top of file
    local line_ini = line_ini and line_ini + 1 or  1
    -- line before delimiter or bottom of file
    local line_end = line_end and line_end - 1 or vim.fn.line("$")

    if line_ini <= line_end then
        M.send_range(line_ini, line_end)
    end
end

function M.send_range(startline, endline)
    -- save registers for restore
    local rv = vim.fn.getreg('"')
    local rt = vim.fn.getregtype('"')
    vim.cmd( startline .. ',' ..  endline .. "yank" )
    local payload = vim.fn.getreg("@\"")
    local prefix = M.repl_prefix()
    local suffix = M.repl_suffix()

    if prefix then
        M.send(prefix)
    end
    M.send(payload)
    if suffix then
        M.send(suffix)
    end
    -- restore
    vim.fn.setreg('"', rv, rt)
end

function M.send_current_line()
    local line = vim.fn.line(".")
    local payload = vim.fn.getline(line)
    M.send(payload .. "\n")
end

function M.send_selected_lines()
    local startline = vim.fn.line("'<")
    local endline = vim.fn.line("'>")
    M.send_range(startline, endline)
end

function M.send_current_word()
    vim.cmd("normal! yiw")
    M.send(vim.fn.getreg("@\"") .. "\n")
end

function M.send_file()
    local filename = vim.fn.expand("%:p")
    local payload = ""
    local lines = vim.fn.readfile(filename)
    for _, line in ipairs(lines) do
        payload = payload .. line .. "\n"
    end

    local prefix = M.repl_prefix()
    local suffix = M.repl_suffix()

    if prefix then
        M.send(prefix)
    end

    M.send(payload)
    if suffix then
        M.send(suffix)
    end

end

function M.send(text)
   local  to_flag = " --to " .. vim.fn.shellescape(kitty_listen_on)
   local cmd = "kitty @" .. to_flag .. " send-text --match id:" .. vim.fn.shellescape(M.id) .. " --stdin"
   vim.fn.system(cmd, text)
   print("text:", text)
   print("cmd:", cmd)
end

function M._store_var()
    vim.cmd("normal! yiw")
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
local function _C(name, cb, desc)
    vim.api.nvim_create_user_command("Kitty" .. name, cb, {
        nargs = "*",
        desc = desc,
    })
end
function M.init_user_commands()
    _C("IPy", function() M.open("/Users/lucanaef/mambaforge/bin/ipython") end, "Open IPython in Kitty")
    _C("Nu", function() M.open("/Users/lucanaef/.cargo/bin/nu") end, "Open Nu in Kitty")
    _C("SendCell", M.send_cell, "Send Cell in Kitty")
    _C("SendCurrentLine", M.send_current_line, "Send Cell in Kitty")
    _C("SendWord", M.send_current_word, "Send Cell in Kitty")
    _C("SendLines", M.send_selected_lines, "Send Cell in Kitty")
    _C("Reload", M.reload, "Reload Kitty (DevTool)")
end

return M
