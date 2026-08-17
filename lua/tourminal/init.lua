local config = require("tourminal.config")
local session = require("tourminal.session")

local M = {}

function M.setup(options)
  config.setup(options)
  session.setup_highlights()
end

function M.start(options)
  session.setup_highlights()
  session.start(options)
end

M.next = session.next
M.previous = session.previous
M.steps = session.steps
M.resume = session.resume
M.reload = session.reload
M.stop = session.stop
M.open_uri = session.open_uri
M.current = session.current
M.statusline = session.statusline

return M
