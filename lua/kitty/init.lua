local kitty = {}
local c = vim.cmd

kitty.path = os.getenv("HOME") .. "/.vim/plugged/kitty.nvim/lua/kitty/" 
-- this is a dev tool which helps reloading
-- the pluggin files
function kitty.reload()
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

function kitty.setup(config)
    c([[
    highlight KittyCellDelimiterColor guifg=#191920 guibg=#1e1f28 
    sign define KittyCellDelimiters linehl=KittyCellDelimiterColor text=>
    ]])
end

function kitty.repl_prefix()
    if vim.bo.filetype == "python" then
        return "%cpaste -q\n"
   end
end

function kitty.repl_suffix()
    if vim.bo.filetype == "python" then
        return "--\n"
    end
end

function kitty.highlight_cell_delimiter()
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



function kitty.open_ipython()
    local script = io.open(kitty.path .. "/open_ipython.sh", "r")
    local query = script:read("*all")
    script:close()
    kitty.id = vim.fn.system(query)
end
function kitty.send_cell()
    local line_ini = vim.fn.search(cell_delimiter, 'bcnW')
    local line_end = vim.fn.search(cell_delimiter, 'nW')

    -- line after delimiter or top of file
    local line_ini = line_ini and line_ini + 1 or  1
    -- line before delimiter or bottom of file
    local line_end = line_end and line_end - 1 or vim.fn.line("$")

    if line_ini <= line_end then
        kitty.send_range(line_ini, line_end)
    end
end

function kitty.send_range(startline, endline)
    -- save registers for restore
    local rv = vim.fn.getreg('"')
    local rt = vim.fn.getregtype('"')
    vim.cmd( startline .. ',' ..  endline .. "yank" )
    local payload = vim.fn.getreg("@\"")
    local prefix = kitty.repl_prefix()
    local suffix = kitty.repl_suffix()

    if prefix then
        kitty.send(prefix)
    end
    kitty.send(payload)
    if suffix then
        kitty.send(suffix)
    end
    -- restore
    vim.fn.setreg('"', rv, rt)
end

function kitty.send_current_line()
    local line = vim.fn.line(".")
    local payload = vim.fn.getline(line)
    kitty.send(payload .. "\n")
end

function kitty.send_selected_lines()
    local startline = vim.fn.line("'<")
    local endline = vim.fn.line("'>")
    kitty.send_range(startline, endline)
end

function kitty.send_current_word()
    vim.cmd("normal! yiw")
    kitty.send(vim.fn.getreg("@\"") .. "\n")
end

function kitty.send_file()
    local filename = vim.fn.expand("%:p")
    local payload = ""
    local lines = vim.fn.readfile(filename)
    for _, line in ipairs(lines) do
        payload = payload .. line .. "\n"
    end

    local prefix = kitty.repl_prefix()
    local suffix = kitty.repl_suffix()

    if prefix then
        kitty.send(prefix)
    end

    kitty.send(payload)
    if suffix then
        kitty.send(suffix)
    end

end

function kitty.send(text)
   local  to_flag = " --to " .. vim.fn.shellescape(kitty_listen_on)
   local cmd = "kitty @" .. to_flag .. " send-text --match id:" .. vim.fn.shellescape(kitty.id) .. " --stdin"
   vim.fn.system(cmd, text)
end

function kitty._store_var()
    vim.cmd("normal! yiw")
    kitty.send("r = " .. vim.fn.getreg("@\"") .. "\n")
end

function kitty.do_imports()
    kitty.send(imports .. "\n")
end

function kitty.fx_current_word()
    kitty._store_var()
    kitty.send(fx_cmd .. "\n")
end

function kitty.hexyl_current_word()
    kitty._store_var()
    kitty.send(hexyl_cmd .. "\n")
end

function kitty.nvim_current_word()
    kitty._store_var()
    kitty.send(nvim_cmd .. "\n")
end

function kitty.vd_current_word()
    kitty._store_var()
    kitty.send(vd_cmd .. "\n")
end
return kitty
