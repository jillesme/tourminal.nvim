local config = require("tourminal.config")

local M = {}

local function absolute(path)
  return vim.fn.fnamemodify(path, ":p")
end

local function invocation(path)
  local command = { config.get().tour_command, "inspect", "--json" }
  local cwd

  if path and path ~= "" then
    path = absolute(path)
    local stat = vim.uv.fs_stat(path)
    if stat and stat.type == "file" and path:lower():sub(-5) == ".tour" then
      vim.list_extend(command, { "--tour", path })
      cwd = vim.fs.dirname(path)
    else
      table.insert(command, path)
      cwd = stat and stat.type == "directory" and path or vim.fs.dirname(path)
    end
    return command, cwd
  end

  local buffer_name = vim.api.nvim_buf_get_name(0)
  cwd = buffer_name ~= "" and vim.fs.dirname(buffer_name) or vim.fn.getcwd()
  table.insert(command, cwd)
  return command, cwd
end

function M.inspect(path, callback)
  local command, cwd = invocation(path)
  local ok, process_or_error = pcall(vim.system, command, {
    cwd = cwd,
    text = true,
  }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local message = vim.trim(result.stderr or "")
        if message == "" then
          message = ("tour inspect exited with status %d"):format(result.code)
        end
        callback(nil, message)
        return
      end

      local decoded_ok, manifest = pcall(vim.json.decode, result.stdout or "")
      if not decoded_ok then
        callback(nil, "tour inspect returned invalid JSON: " .. tostring(manifest))
        return
      end
      if type(manifest) ~= "table" or manifest.apiVersion ~= 1 then
        callback(nil, "tour inspect returned an unsupported API version")
        return
      end
      if type(manifest.tours) ~= "table" then
        callback(nil, "tour inspect returned a malformed manifest")
        return
      end
      callback(manifest, nil)
    end)
  end)

  if not ok then
    vim.schedule(function()
      callback(nil, "unable to run " .. config.get().tour_command .. ": " .. tostring(process_or_error))
    end)
  end
end

return M
