local telescope = require("telescope")
local pickers = require "telescope.pickers"
local conf = require('telescope.config').values
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local setup_opts = {
  auto_quoting = true,
  mappings = {},
}

local cmake = function(opts)
  opts = vim.tbl_extend("force", setup_opts, opts or {})

  local target_finder = function()
    local buildFolder = require("util").get_root() .. "/build"
    local bashCommand = "cmake --build " .. buildFolder .. " --target help"

    -- Execute the Bash command and capture the output
    local fileOutput = {}
    local handle = io.popen(bashCommand)
    local result = handle:read("*a")
    handle:close()

    -- Process the output and populate the Lua table
    for line in result:gmatch("[^\r\n]+") do
      if line:match("^%.%.%.%s*(.+)") then
        local content = line:match("^%.%.%.%s*(%S+)")
        table.insert(fileOutput, content)
      end
    end

    return fileOutput
  end

  pickers.new(opts, {
    prompt_title = "CMake",
    finder =
        finders.new_table {
          results = target_finder()
        },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local buildFolder = require("util").get_root() .. "/build"
        local bashCommand = "cmake --build " .. buildFolder .. " --target " .. selection[1]
        local exitCode = os.execute(bashCommand)

        -- Check the exit status of the command
        if exitCode == 0 then
          print("Command executed successfully")
        else
          print("Command failed with exit status:", exitCode)
        end
      end)
      return true
    end,
  }):find()
end

return telescope.register_extension {
  exports = {
    cmake = cmake,
  },
}
