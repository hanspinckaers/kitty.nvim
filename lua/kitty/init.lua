local kitty = {}
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

function kitty.get_cell()
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
  kitty.send(vim.fn.getreg("@\""))
  -- restore
  vim.fn.setreg('"', rv, rt)
end

function kitty.send(text)
   local  to_flag = " --to " .. vim.fn.shellescape(kitty_listen_on)
   local last_tab = kitty.get_last_tab()
   local cmd = "kitty @" .. to_flag .. " send-text --match id:" .. vim.fn.shellescape(last_tab) .. " --stdin"
   vim.fn.system(cmd, text)
end

function kitty.setup()
    print("kitty setup")
end


return kitty
