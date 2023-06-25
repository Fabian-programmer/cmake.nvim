local overseer = require("overseer")

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
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local target = action_state.get_selected_entry()[1]
        local buildFolder = require("util").get_root() .. "/build"

        actions.close(prompt_bufnr)
        local task = overseer.new_task({
          name = "- Build",
          strategy = {
            "orchestrator",
            tasks = { {
              "shell",
              name = "- Build this target → " .. target,
              cmd = "cmake --build " .. buildFolder .. " --target " .. target
            }, },
          },
        })
        task:start()
        vim.cmd("OverseerOpen")
      end)

      local buildAndRunTarget = function()
        local target = action_state.get_selected_entry()[1]
        local buildFolder = require("util").get_root() .. "/build"
        local binFolder = require("util").get_root() .. "/bin"
        local args_string = vim.fn.input("Args: ")
        vim.cmd("stopinsert")

        local task = overseer.new_task({
          name = "- Build and Run",
          strategy = {
            "orchestrator",
            tasks = { {
              "shell",
              name = "- Build this target → " .. target,
              cmd = "cmake --build " .. buildFolder .. " --target " .. target
            },
              {
                "shell",
                name = "- Run this target → " .. target,
                cmd = binFolder .. "/" .. target .. " " .. args_string,
              },
            },
          },
        })
        task:start()
        vim.cmd("OverseerOpen")
      end

      local debugTarget = function()
        local target = action_state.get_selected_entry()[1]
        vim.api.nvim_win_close(0, true)
        vim.cmd("stopinsert")
        local binFolder = require("util").get_root() .. "/bin"
        local args_string = vim.fn.input("Args: ")

        local config = {
          type = "cppdbg",
          request = "launch",
          program = binFolder .. "/" .. target,
          args = function()
            local args = {}
            for word in args_string:gmatch("%S+") do
              table.insert(args, word)
            end
            return args
          end,
          cwd = "${workspaceFolder}",
          stopAtEntry = true,
          setupCommands = {
            {
              text = "-enable-pretty-printing",
              description = "enable pretty printing",
              ignoreFailures = false,
            },
          },
        }
        vim.schedule(function()
          require("dap").run(config)
        end)
      end

      map('n', '<F4>', buildAndRunTarget)
      map('i', '<F4>', buildAndRunTarget)

      map('n', '<F5>', debugTarget)
      map('i', '<F5>', debugTarget)

      return true
    end,
  }):find()
end

return telescope.register_extension {
  exports = {
    cmake = cmake,
  },
}
