local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. (": expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)))
  end
end

local function press(key)
  vim.api.nvim_feedkeys(vim.keycode(key), "mx", false)
end

local function buffer_mapping(buffer, key)
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buffer, "n")) do
    if mapping.lhs == key then
      return mapping
    end
  end
end

local function run()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/.tours", "p")
  root = assert(vim.uv.fs_realpath(root))
  vim.fn.writefile({ "local intro = true", "", "local answer = 42", "return answer" }, root .. "/main.lua")
  vim.env.TOUR_TEST_ROOT = root

  local tourminal = require("tourminal")
  local session = require("tourminal.session")
  local ui = require("tourminal.ui")

  tourminal.start({ path = root })
  assert(vim.wait(5000, function()
    return tourminal.current() ~= nil and session._state().mark_buffer ~= nil
  end), "tour did not start")

  local current = tourminal.current()
  assert_equal(current.title, "Integration tour", "tour title")
  assert_equal(current.step, 1, "initial step")
  assert_equal(vim.api.nvim_buf_get_name(0), root .. "/main.lua", "file buffer")
  assert_equal(vim.api.nvim_win_get_cursor(0)[1], 3, "target line")
  assert(#vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, {}) >= 2, "expected target extmarks")
  assert(ui.note_window(), "expected note window")
  local note_text = table.concat(vim.api.nvim_buf_get_lines(ui.note_buffer(), 0, -1, false), "\n")
  assert(note_text:find("were not executed", 1, true), "command safety warning is missing")

  press("n")
  assert_equal(tourminal.current().step, 2, "content step")
  assert_equal(vim.api.nvim_buf_get_name(0), root .. "/main.lua", "content step should retain source")
  press("p")
  assert_equal(tourminal.current().step, 1, "mapped previous step")
  press("n")
  assert_equal(tourminal.current().step, 2, "mapped next step")

  tourminal.next()
  assert_equal(tourminal.current().step, 3, "embedded step")
  local embedded = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  assert(embedded:find("local embedded = true", 1, true), "embedded source is missing")
  assert_equal(vim.api.nvim_win_get_cursor(0)[1], 2, "embedded target line")

  tourminal.next()
  assert(session._state().complete, "tour should be complete")
  tourminal.previous()
  assert(not session._state().complete, "previous should return from completion")
  assert_equal(tourminal.current().step, 3, "completion return step")

  tourminal.stop({ silent = true })
  assert_equal(tourminal.current(), nil, "stopped tour")
  assert_equal(ui.note_window(), nil, "closed note window")

  vim.cmd("lcd " .. vim.fn.fnameescape(vim.fs.dirname(root)))
  local oil_buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(oil_buffer, "oil://" .. root .. "/")
  vim.bo[oil_buffer].buftype = "acwrite"
  vim.keymap.set("n", "n", function()
    vim.g.tourminal_test_oil_mapping = true
  end, { buffer = oil_buffer, desc = "Oil next" })
  vim.api.nvim_win_set_buf(0, oil_buffer)
  vim.env.TOUR_EXPECT_WORKSPACE = root

  tourminal.start({ step = 2 })
  assert(vim.wait(5000, function()
    return tourminal.current() ~= nil and tourminal.current().step == 2
  end), "tour did not start from Oil buffer")
  assert_equal(tourminal.current().title, "Integration tour", "Oil tour title")
  assert_equal(vim.api.nvim_buf_get_name(0), "oil://" .. root .. "/", "Oil workspace buffer")
  assert_equal(buffer_mapping(oil_buffer, "n").desc, "Tourminal next", "Oil next mapping")
  press("n")
  assert_equal(tourminal.current().step, 3, "mapped Oil next step")
  assert_equal(buffer_mapping(oil_buffer, "n").desc, "Oil next", "restored Oil mapping")
  tourminal.stop({ silent = true })

  vim.env.TOUR_EXPECT_WORKSPACE = nil
  vim.fn.delete(root, "rf")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit")
else
  print("tourminal.nvim integration test passed")
  vim.cmd("qa!")
end
