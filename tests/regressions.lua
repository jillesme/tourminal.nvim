local function run()
  local backend = require("tourminal.backend")
  local session = require("tourminal.session")
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  root = assert(vim.uv.fs_realpath(root))
  local path = root .. "/source.txt"
  vim.fn.writefile({ "must not be loaded" }, path)
  local function tour(title, count)
    local steps = {}
    for number = 1, count or 1 do
      steps[number] = { number = number, label = "Step", description = "Hello", resolved = { kind = "content" } }
    end
    return { title = title, path = root .. "/" .. title .. ".tour", steps = steps }
  end
  local manifest
  backend.inspect = function(_, callback) callback(manifest, nil) end

  -- Older backends may retain a file path alongside their rejection.
  for _, message in ipairs({ "source is binary or not UTF-8", "source is larger than 2 MiB", "open source: no such file" }) do
    local rejected = tour("Rejected")
    rejected.steps[1].error = message
    rejected.steps[1].resolved = { kind = "file", path = path }
    manifest = { root = root, tours = { rejected } }
    session.start({ path = root })
    assert(vim.fn.bufnr(path) == -1, "rejected source acquired a buffer")
    local ui = require("tourminal.ui")
    local notes = table.concat(vim.api.nvim_buf_get_lines(ui.note_buffer(), 0, -1, false), "\n")
    assert(notes:find(message, 1, true), "rejection was not displayed")
    session.stop({ silent = true })
  end

  local pickers = {}
  vim.ui.select = function(items, _, callback)
    table.insert(pickers, { items = items, callback = callback })
  end
  manifest = { root = root, tours = { tour("Old A"), tour("Old B") } }
  session.start({ path = root })
  session.stop({ silent = true })
  pickers[1].callback(pickers[1].items[1])
  assert(session.current() == nil, "stale picker restarted a stopped tour")

  session.start({ path = root })
  manifest = { root = root, tours = { tour("New") } }
  session.start({ path = root })
  pickers[2].callback(pickers[2].items[1])
  assert(session.current().title == "New", "stale picker replaced a new tour")

  manifest = { root = root, tours = { tour("Long", 2) } }
  session.start({ path = root })
  session.steps()
  manifest = { root = root, tours = { tour("Short") } }
  session.start({ path = root })
  pickers[3].callback(pickers[3].items[2])
  assert(session.current().title == "Short" and session.current().step == 1, "stale step picker changed a new tour")

  -- A linked-tour transition does not change the backend request counter.
  local first, second = tour("First", 2), tour("Second")
  first.nextTourPath = second.path
  manifest = { root = root, tours = { first, second } }
  session.start({ path = root })
  pickers[4].callback(first)
  session.steps()
  session.next()
  session.next()
  pickers[5].callback(first.steps[2])
  assert(session.current().title == "Second" and session.current().step == 1, "old step picker changed a linked tour")
  session.stop({ silent = true })
  vim.fn.delete(root, "rf")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit")
else
  print("tourminal.nvim regression tests passed")
  vim.cmd("qa!")
end
