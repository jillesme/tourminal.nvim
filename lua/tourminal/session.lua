local backend = require("tourminal.backend")
local ui = require("tourminal.ui")

local M = {}

local namespace = vim.api.nvim_create_namespace("tourminal.nvim")
local state = {
  request = 0,
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Tourminal" })
end

local function valid_window(window)
  return window and vim.api.nvim_win_is_valid(window)
end

local function ensure_code_window()
  if valid_window(state.code_window) then
    return state.code_window
  end
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if window ~= ui.note_window() and vim.api.nvim_win_get_config(window).relative == "" then
      state.code_window = window
      return window
    end
  end
  state.code_window = vim.api.nvim_get_current_win()
  return state.code_window
end

local function clear_highlights()
  if state.mark_buffer and vim.api.nvim_buf_is_valid(state.mark_buffer) then
    vim.api.nvim_buf_clear_namespace(state.mark_buffer, namespace, 0, -1)
  end
  state.mark_buffer = nil
end

local function highlight(buffer, step)
  local resolved = step.resolved or {}
  local line_count = vim.api.nvim_buf_line_count(buffer)
  local target = math.max(1, math.min(resolved.targetLine or 1, line_count))
  local selection_start = resolved.selectionStart or 0
  local selection_end = resolved.selectionEnd or 0

  if selection_start > 0 and selection_end >= selection_start then
    local last = math.min(selection_end, line_count)
    for line = selection_start, last do
      vim.api.nvim_buf_set_extmark(buffer, namespace, line - 1, 0, {
        line_hl_group = "TourminalSelection",
        priority = 150,
      })
    end
  else
    vim.api.nvim_buf_set_extmark(buffer, namespace, target - 1, 0, {
      line_hl_group = "TourminalTarget",
      priority = 150,
    })
  end

  vim.api.nvim_buf_set_extmark(buffer, namespace, target - 1, 0, {
    sign_text = "▶",
    sign_hl_group = "TourminalTargetSign",
    number_hl_group = "TourminalTargetSign",
    priority = 200,
  })
  state.mark_buffer = buffer
  return target
end

local function center(window, line)
  vim.api.nvim_win_set_cursor(window, { line, 0 })
  vim.api.nvim_win_call(window, function()
    vim.cmd("normal! zz")
  end)
end

local function replace_scratch(buffer)
  local previous = state.scratch_buffer
  state.scratch_buffer = buffer
  if previous and previous ~= buffer and vim.api.nvim_buf_is_valid(previous) then
    pcall(vim.api.nvim_buf_delete, previous, { force = true })
  end
end

local function open_file(step)
  local path = step.resolved and step.resolved.path
  if not path or path == "" then
    return nil, "this step has no resolved file path"
  end
  local buffer = vim.fn.bufadd(path)
  local ok, load_error = pcall(vim.fn.bufload, buffer)
  if not ok then
    return nil, tostring(load_error)
  end
  vim.bo[buffer].buflisted = true
  local window = ensure_code_window()
  local switched, switch_error = pcall(vim.api.nvim_win_set_buf, window, buffer)
  if not switched then
    return nil, tostring(switch_error)
  end
  replace_scratch(nil)
  local target = highlight(buffer, step)
  center(window, target)
  return window
end

local function scratch_buffer(step, directory)
  local buffer = vim.api.nvim_create_buf(false, true)
  local name = ("tourminal://%s/%d"):format(directory and "directory" or "embedded", step.number)
  pcall(vim.api.nvim_buf_set_name, buffer, name)
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  local source = step.resolved and step.resolved.source or ""
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(source, "\n", { plain = true }))
  vim.bo[buffer].modifiable = false
  if directory then
    vim.bo[buffer].filetype = "tourminal-directory"
  elseif step.file and step.file ~= "" then
    local filetype = vim.filetype.match({ filename = step.file })
    if filetype then
      vim.bo[buffer].filetype = filetype
    end
  end
  return buffer
end

local function open_scratch(step, directory)
  local buffer = scratch_buffer(step, directory)
  local window = ensure_code_window()
  local ok, switch_error = pcall(vim.api.nvim_win_set_buf, window, buffer)
  if not ok then
    pcall(vim.api.nvim_buf_delete, buffer, { force = true })
    return nil, tostring(switch_error)
  end
  replace_scratch(buffer)
  local target = highlight(buffer, step)
  center(window, target)
  return window
end

local function emit_user_event(pattern, data)
  pcall(vim.api.nvim_exec_autocmds, "User", {
    pattern = pattern,
    data = data,
  })
end

local function show_step()
  if not state.tour or not state.step_index then
    return
  end
  state.complete = false
  clear_highlights()
  local step = state.tour.steps[state.step_index]
  local kind = step.resolved and step.resolved.kind or "content"
  local code_window = ensure_code_window()
  local open_error

  if kind == "file" then
    code_window, open_error = open_file(step)
  elseif kind == "embedded" then
    code_window, open_error = open_scratch(step, false)
  elseif kind == "directory" then
    code_window, open_error = open_scratch(step, true)
  end
  if open_error and not step.error then
    step.error = open_error
  end

  ui.show_step(state.tour, step, code_window or ensure_code_window())
  emit_user_event("TourminalStep", {
    tour = state.tour.title,
    step = state.step_index,
    total = #state.tour.steps,
  })
end

local function begin_tour(tour, step)
  if not tour or not tour.steps or #tour.steps == 0 then
    notify("The selected tour has no steps", vim.log.levels.ERROR)
    return
  end
  state.tour = tour
  state.step_index = math.max(1, math.min(step or 1, #tour.steps))
  show_step()
  emit_user_event("TourminalStart", { tour = tour.title })
end

local function choose_tour(manifest, requested_step)
  if #manifest.tours == 0 then
    local message = "No CodeTours found in " .. (manifest.root or "this workspace")
    if manifest.diagnostics and #manifest.diagnostics > 0 then
      message = message .. "\n" .. table.concat(manifest.diagnostics, "\n")
    end
    notify(message, vim.log.levels.WARN)
    return
  end
  if #manifest.tours == 1 then
    begin_tour(manifest.tours[1], requested_step)
    return
  end

  vim.ui.select(manifest.tours, {
    prompt = "Choose a CodeTour",
    kind = "tourminal",
    format_item = function(tour)
      return (tour.primary and "★ " or "") .. tour.title .. (" (%d steps)"):format(#tour.steps)
    end,
  }, function(choice)
    if choice then
      begin_tour(choice, requested_step)
    end
  end)
end

function M.start(options)
  options = options or {}
  M.stop({ silent = true })
  state.code_window = vim.api.nvim_get_current_win()
  state.source_path = options.path
  state.request = state.request + 1
  local request = state.request

  backend.inspect(options.path, function(manifest, err)
    if request ~= state.request then
      return
    end
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    state.manifest = manifest
    choose_tour(manifest, options.step)
  end)
end

function M.next()
  if not state.tour then
    notify("No active tour", vim.log.levels.WARN)
    return
  end
  if state.complete then
    return
  end
  if state.step_index < #state.tour.steps then
    state.step_index = state.step_index + 1
    show_step()
    return
  end
  if state.tour.nextTourPath and state.tour.nextTourPath ~= "" then
    for _, candidate in ipairs(state.manifest.tours) do
      if candidate.path == state.tour.nextTourPath then
        begin_tour(candidate, 1)
        return
      end
    end
  end
  if state.tour.nextTour and state.tour.nextTour ~= "" then
    notify('Next tour "' .. state.tour.nextTour .. '" was not found', vim.log.levels.ERROR)
    return
  end
  state.complete = true
  clear_highlights()
  ui.show_complete(state.tour, ensure_code_window())
  emit_user_event("TourminalComplete", { tour = state.tour.title })
end

function M.previous()
  if not state.tour then
    notify("No active tour", vim.log.levels.WARN)
    return
  end
  if state.complete then
    state.complete = false
    show_step()
    return
  end
  if state.step_index > 1 then
    state.step_index = state.step_index - 1
    show_step()
  end
end

function M.steps()
  if not state.tour then
    notify("No active tour", vim.log.levels.WARN)
    return
  end
  vim.ui.select(state.tour.steps, {
    prompt = state.tour.title .. " — Steps",
    kind = "tourminal-steps",
    format_item = function(step)
      local current = step.number == state.step_index and " • current" or ""
      return ("%d. %s%s"):format(step.number, step.label, current)
    end,
  }, function(choice)
    if choice then
      state.step_index = choice.number
      show_step()
    end
  end)
end

function M.resume()
  if not state.tour then
    notify("No active tour", vim.log.levels.WARN)
    return
  end
  if state.complete then
    ui.show_complete(state.tour, ensure_code_window())
  else
    show_step()
  end
end

function M.reload()
  if not state.tour then
    notify("No active tour", vim.log.levels.WARN)
    return
  end
  local tour_path = state.tour.path
  local tour_title = state.tour.title
  local step_index = state.step_index
  state.request = state.request + 1
  local request = state.request
  backend.inspect(state.source_path, function(manifest, err)
    if request ~= state.request then
      return
    end
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    state.manifest = manifest
    for _, candidate in ipairs(manifest.tours) do
      if candidate.path == tour_path or candidate.title == tour_title then
        begin_tour(candidate, step_index)
        return
      end
    end
    notify("The active tour is no longer available", vim.log.levels.ERROR)
  end)
end

function M.open_uri()
  if not state.tour then
    return
  end
  local step = state.tour.steps[state.step_index]
  if not step.uri or step.uri == "" then
    notify("The current step has no URI", vim.log.levels.WARN)
    return
  end
  local ok, command_or_error, open_error = pcall(vim.ui.open, step.uri)
  if not ok or not command_or_error then
    notify("Unable to open URI: " .. tostring(open_error or command_or_error), vim.log.levels.ERROR)
  end
end

function M.stop(options)
  options = options or {}
  local was_active = state.tour ~= nil
  state.request = state.request + 1
  clear_highlights()
  ui.close()
  state.manifest = nil
  state.tour = nil
  state.step_index = nil
  state.complete = false
  state.code_window = nil
  state.source_path = nil
  if state.scratch_buffer and vim.api.nvim_buf_is_valid(state.scratch_buffer) then
    pcall(vim.api.nvim_buf_delete, state.scratch_buffer, { force = true })
  end
  state.scratch_buffer = nil
  if was_active then
    emit_user_event("TourminalStop", {})
    if not options.silent then
      notify("Tour stopped")
    end
  end
end

function M.current()
  if not state.tour then
    return nil
  end
  return {
    title = state.tour.title,
    path = state.tour.path,
    step = state.step_index,
    total = #state.tour.steps,
    complete = state.complete,
  }
end

function M.statusline()
  local current = M.current()
  if not current then
    return ""
  end
  return ("Tour: %s %d/%d"):format(current.title, current.step, current.total)
end

function M._state()
  return state
end

function M.setup_highlights()
  vim.api.nvim_set_hl(0, "TourminalTarget", { default = true, link = "CursorLine" })
  vim.api.nvim_set_hl(0, "TourminalSelection", { default = true, link = "Visual" })
  vim.api.nvim_set_hl(0, "TourminalTargetSign", { default = true, link = "DiagnosticInfo" })
end

return M
