local kitty = {}

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

function kitty.get_last_tab()
    local query = [[ 
    kitty @ ls | 
    jq '.[] | 
    .tabs[] |
    select(.is_focused==true) |
    .active_window_history[]' |
    head -n 2 |
    tail -n 1 | 
    tr -d '\n'
    ]]
    return vim.fn.system(query)
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
    vim.cmd("yiw")
    kitty.send(vim.fn.getreg("@\"" .. "\n"))
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
   local last_tab = kitty.get_last_tab()
   local cmd = "kitty @" .. to_flag .. " send-text --match id:" .. vim.fn.shellescape(last_tab) .. " --stdin"
   vim.fn.system(cmd, text)
end

return kitty
