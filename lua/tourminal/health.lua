local config = require("tourminal.config")

local M = {}

function M.check()
  vim.health.start("tourminal.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10 or newer")
  else
    vim.health.error("Neovim 0.10 or newer is required")
  end

  local command = config.get().tour_command
  if vim.fn.executable(command) ~= 1 then
    vim.health.error(command .. " was not found on PATH", {
      "Install Tourminal before using this plugin.",
      "Homebrew: brew install jillesme/tap/tourminal",
    })
    return
  end
  vim.health.ok(command .. " is executable")

  local ok, result = pcall(function()
    return vim.system({ command, "inspect", "--help" }, { text = true }):wait(3000)
  end)
  if not ok then
    vim.health.error("Unable to query Tourminal: " .. tostring(result))
    return
  end
  local output = (result.stdout or "") .. (result.stderr or "")
  if result.code == 0 and output:find("%-%-json") then
    vim.health.ok("Tourminal supports the editor manifest API")
  else
    vim.health.error("This Tourminal build does not support `tour inspect --json`", {
      "Upgrade to Tourminal 0.1.4 or newer.",
    })
  end
end

return M
