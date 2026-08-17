local M = {}

local defaults = {
  tour_command = "tour",
  note = {
    width = 72,
    max_height = 18,
    border = "rounded",
    winblend = 0,
  },
}

local options = vim.deepcopy(defaults)

function M.setup(user_options)
  if user_options ~= nil and type(user_options) ~= "table" then
    error("tourminal.setup options must be a table")
  end
  options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_options or {})
  if type(options.tour_command) ~= "string" or options.tour_command == "" then
    error("tourminal tour_command must be a non-empty string")
  end
  if type(options.note) ~= "table" then
    error("tourminal note options must be a table")
  end
  return options
end

function M.get()
  return options
end

return M
