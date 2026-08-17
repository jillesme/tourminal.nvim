if vim.g.loaded_tourminal_nvim then
  return
end
vim.g.loaded_tourminal_nvim = true

local function call(method)
  return function()
    require("tourminal")[method]()
  end
end

vim.api.nvim_create_user_command("Tour", function(opts)
  require("tourminal").start({ path = opts.args ~= "" and opts.args or nil })
end, {
  nargs = "?",
  complete = "file",
  desc = "Start a CodeTour",
})

vim.api.nvim_create_user_command("TourNext", call("next"), {
  desc = "Open the next CodeTour step",
})

vim.api.nvim_create_user_command("TourPrev", call("previous"), {
  desc = "Open the previous CodeTour step",
})

vim.api.nvim_create_user_command("TourSteps", call("steps"), {
  desc = "Choose a step in the active CodeTour",
})

vim.api.nvim_create_user_command("TourResume", call("resume"), {
  desc = "Return to the active CodeTour step",
})

vim.api.nvim_create_user_command("TourReload", call("reload"), {
  desc = "Reload the active CodeTour from disk",
})

vim.api.nvim_create_user_command("TourStop", call("stop"), {
  desc = "Stop the active CodeTour",
})
