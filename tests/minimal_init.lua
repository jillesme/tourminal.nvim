local root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
local user_site = vim.fn.stdpath("data") .. "/site"
vim.opt.runtimepath:remove(user_site)
vim.opt.runtimepath:remove(user_site .. "/after")
vim.opt.packpath:remove(user_site)
vim.opt.runtimepath:prepend(root)

require("tourminal").setup({
  tour_command = root .. "/tests/fake-tour",
  note = {
    width = 60,
    max_height = 12,
  },
})
