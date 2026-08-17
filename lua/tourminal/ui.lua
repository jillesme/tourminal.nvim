local config = require("tourminal.config")

local M = {}

local note_buffer
local note_window

local function valid_buffer(buffer)
  return buffer and vim.api.nvim_buf_is_valid(buffer)
end

local function valid_window(window)
  return window and vim.api.nvim_win_is_valid(window)
end

local function ensure_buffer()
  if valid_buffer(note_buffer) then
    return note_buffer
  end

  note_buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(note_buffer, "tourminal://notes")
  vim.bo[note_buffer].buftype = "nofile"
  vim.bo[note_buffer].bufhidden = "hide"
  vim.bo[note_buffer].swapfile = false

  local mappings = {
    n = "next",
    p = "previous",
    g = "steps",
    r = "reload",
    q = "stop",
    o = "open_uri",
  }
  for key, method in pairs(mappings) do
    vim.keymap.set("n", key, function()
      require("tourminal")[method]()
    end, {
      buffer = note_buffer,
      silent = true,
      nowait = true,
      desc = "Tourminal " .. method,
    })
  end

  return note_buffer
end

local function note_lines(tour, step)
  local lines = vim.split(step.description or "", "\n", { plain = true })
  local function quote(message)
    if message and message ~= "" then
      table.insert(lines, "")
      for _, line in ipairs(vim.split(message, "\n", { plain = true })) do
        table.insert(lines, "> " .. line)
      end
    end
  end

  if step.resolved and step.resolved.kind == "uri" and step.uri then
    table.insert(lines, "")
    table.insert(lines, "**URI:** " .. step.uri)
    table.insert(lines, "")
    table.insert(lines, "Press `o` in this window to open it.")
  end
  if step.view and step.view ~= "" then
    quote("The VS Code view `" .. step.view .. "` is not available in Neovim.")
  end
  if step.commands and #step.commands > 0 then
    quote(("Safety: this step contains %d command(s). They were not executed."):format(#step.commands))
  end
  quote(tour.warning and ("Tour warning: " .. tour.warning) or nil)
  quote(step.error and ("Step warning: " .. step.error) or nil)

  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "`n` next · `p` previous · `g` steps · `r` reload · `q` stop")
  return lines
end

local function complete_lines(tour)
  return {
    "# Tour complete",
    "",
    "You finished **" .. tour.title .. "**.",
    "",
    "`p` return to the final step · `q` stop",
  }
end

local function dimensions(lines, code_window)
  local note = config.get().note
  local editor_width = math.max(1, vim.o.columns - 4)
  local code_width = valid_window(code_window) and vim.api.nvim_win_get_width(code_window) or editor_width
  local available_width = math.max(1, math.min(editor_width, code_width - 2))
  local width = math.max(1, math.min(note.width, available_width))
  local rows = 0
  for _, line in ipairs(lines) do
    rows = rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / math.max(1, width)))
  end
  local available_height = math.max(1, vim.o.lines - vim.o.cmdheight - 4)
  local height = math.max(1, math.min(rows, note.max_height, available_height))
  return width, height
end

local function window_config(code_window, target_line, width, height, title)
  local result = {
    width = width,
    height = height,
    style = "minimal",
    border = config.get().note.border,
    title = vim.fn.strcharpart(title, 0, math.max(1, width - 2)),
    title_pos = "center",
  }
  if valid_window(code_window) and target_line and target_line > 0 then
    result.relative = "win"
    result.win = code_window
    result.bufpos = { target_line - 1, 0 }
    result.anchor = "SW"
    result.row = 0
    result.col = 0
  else
    result.relative = "editor"
    result.row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
    result.col = math.max(0, math.floor((vim.o.columns - width) / 2))
  end
  return result
end

local function render(lines, code_window, target_line, title)
  local buffer = ensure_buffer()
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  if vim.bo[buffer].filetype ~= "markdown" then
    vim.bo[buffer].filetype = "markdown"
  end

  local width, height = dimensions(lines, code_window)
  local options = window_config(code_window, target_line, width, height, title)
  if valid_window(note_window) then
    vim.api.nvim_win_set_buf(note_window, buffer)
    vim.api.nvim_win_set_config(note_window, options)
  else
    note_window = vim.api.nvim_open_win(buffer, false, options)
  end

  vim.wo[note_window].wrap = true
  vim.wo[note_window].linebreak = true
  vim.wo[note_window].conceallevel = 2
  vim.wo[note_window].concealcursor = "n"
  vim.wo[note_window].cursorline = false
  vim.wo[note_window].winblend = config.get().note.winblend
  pcall(vim.treesitter.start, buffer, "markdown")
end

function M.show_step(tour, step, code_window)
  local title = (" Tourminal · %s · %d/%d "):format(tour.title, step.number, #tour.steps)
  local target_line = step.resolved and step.resolved.targetLine or nil
  render(note_lines(tour, step), code_window, target_line, title)
end

function M.show_complete(tour, code_window)
  render(complete_lines(tour), code_window, nil, " Tourminal · Complete ")
end

function M.close()
  if valid_window(note_window) then
    pcall(vim.api.nvim_win_close, note_window, true)
  end
  note_window = nil
  if valid_buffer(note_buffer) then
    pcall(vim.api.nvim_buf_delete, note_buffer, { force = true })
  end
  note_buffer = nil
end

function M.note_window()
  return valid_window(note_window) and note_window or nil
end

function M.note_buffer()
  return valid_buffer(note_buffer) and note_buffer or nil
end

return M
