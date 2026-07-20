local M = {}

--- Strip ANSI/CSI escapes (SGR colors, erase-line, cursor moves) and CRs.
function M.strip(s)
  s = (s or ""):gsub("\27%[[0-9;?]*%a", "")
  return (s:gsub("\r", ""))
end

function M.err(msg)
  vim.notify("squix: " .. M.strip(tostring(msg)), vim.log.levels.ERROR)
end

function M.fail(out)
  local msg = vim.trim(out.stderr or "")
  if msg == "" then msg = vim.trim(out.stdout or "") end
  if msg == "" then msg = "failed" end
  M.err(msg)
end

function M.has_squix()
  if vim.fn.executable("squix") ~= 0 then return true end
  M.err("'squix' not found in PATH. Install squix first.")
  return false
end

--- Drop leading blank or `--` sql comment lines
function M.get_sql(line1, line2)
  local lines = vim.fn.getline(line1, line2)
  if type(lines) == "string" then lines = { lines } end
  local i = 1
  while i <= #lines do
    local l = vim.trim(lines[i])
    if l == "" or l:sub(1, 2) == "--" then
      i = i + 1
    else
      break
    end
  end
  return vim.trim(table.concat(lines, "\n", i))
end

--- Parse `squix list <connections|queries>` (run with NO_COLOR=1) into { name, label }
function M.parse_items(stdout, skip_phrase)
  local entries = {}
  for _, line in ipairs(vim.split(stdout or "", "\n", { plain = true })) do
    line = vim.trim(M.strip(line))
    if line ~= "" and (not skip_phrase or not line:lower():find(skip_phrase, 1, true)) then
      local name = line:match("^%S+%s+(%S+)")
      if name then table.insert(entries, { name = name, label = line }) end
    end
  end
  return entries
end

return M
