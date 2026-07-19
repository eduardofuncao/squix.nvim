local util = require("squix.util")

local M = {}

local defaults = {
  hide_query = true, -- hide query name + SQL in the TUI (already in the editor)
  term_keymaps = true, -- in-TUI <C-w>hjkl window navigation; false sends keys raw to the TUI
  hide_statusline = true, -- set laststatus=0 while the squix TUI is focused (splits have no per-window statusline)
  window = {
    position = "botright", -- "botright" | "topleft" | "vertical" | "float"
    split_ratio = 0.4,
    auto_focus = true, -- focus (and enter) the TUI window when it opens
    float = {
      width = "80%", height = "80%", row = "center", col = "center",
      relative = "editor", border = "rounded",
    },
  },
  keymaps = {                 -- none mapped by default; set any to a key to enable
    run = false,
    run_named_query = false,
    add = false,
    switch = false,
    init = false,
    status = false,
    tables = false,
  },
}

M.config = vim.deepcopy(defaults)
M.state = {} -- { win, buf } of the tracked squix TUI terminal

--- Line range of the blank-delimited paragraph around the cursor (vim's `vip`).
local function paragraph_range()
  local first = vim.fn.search("^$", "bnW")
  local last = vim.fn.search("^$", "nW")
  return (first == 0 and 1 or first + 1), (last == 0 and vim.fn.line("$") or last - 1)
end

--- An explicit command range/selection, else the cursor's paragraph.
local function sql_range(opts)
  if opts.range and opts.range >= 1 then return opts.line1, opts.line2 end
  return paragraph_range()
end

local function close_win_buf(win, buf)
  if win and vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
  if buf and vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
end

local function close_term()
  close_win_buf(M.state.win, M.state.buf)
  M.state.win, M.state.buf = nil, nil
end

--- Resolve a float dimension: number, or "NN%" of `max`.
local function float_dim(value, max)
  if value == nil then return math.floor(max * 0.8) end
  if type(value) == "string" then
    local p = value:match("^(%d+)%%$")
    if p then return math.floor(max * tonumber(p) / 100) end
    return tonumber(value) or math.floor(max * 0.8)
  end
  return math.floor(value)
end

--- Resolve a float position: number, "center", or "NN%" of `max` (clamped).
local function float_pos(value, size, max)
  local pos
  if value == "center" then
    pos = math.floor((max - size) / 2)
  elseif type(value) == "string" then
    local p = value:match("^(%d+)%%$")
    pos = p and math.floor(max * tonumber(p) / 100) or (tonumber(value) or 0)
  else
    pos = value or 0
  end
  return math.max(0, math.min(math.floor(pos), max - size))
end

--- Open the TUI window (split or float); returns (win, buf).
local function open_window(cfg)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local win
  if cfg.position == "float" then
    local f = cfg.float or {}
    local ew, eh = vim.o.columns, vim.o.lines - vim.o.cmdheight - 1
    local width, height = float_dim(f.width, ew), float_dim(f.height, eh)
    win = vim.api.nvim_open_win(buf, true, {
      relative = f.relative or "editor",
      width = width,
      height = height,
      row = float_pos(f.row, height, eh),
      col = float_pos(f.col, width, ew),
      border = f.border or "rounded",
      style = "minimal",
    })
  else
    local vertical = cfg.position == "vertical"
    vim.cmd((cfg.position or "botright") .. " split")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    local ratio = cfg.split_ratio or 0.4
    if vertical then
      vim.cmd("vertical resize " .. math.floor(vim.o.columns * ratio))
    else
      vim.cmd("resize " .. math.floor(vim.o.lines * ratio))
    end
  end
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = false
  return win, buf
end

--- Re-enter terminal mode when a squix terminal window is entered.
local function force_insert()
  if vim.bo.buftype == "terminal" and vim.api.nvim_get_mode().mode ~= "t" then
    vim.schedule(function() pcall(vim.cmd, "startinsert") end)
  end
end

local function configure_terminal(buf)
  local grp = vim.api.nvim_create_augroup("SquixTerm_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "FocusGained" }, {
    group = grp, buffer = buf, callback = force_insert,
  })
  if M.config.term_keymaps then
    local o = { buffer = buf, silent = true }
    for _, d in ipairs({ "h", "j", "k", "l" }) do
      vim.keymap.set("t", "<C-w>" .. d, "<C-\\><C-n><C-w>" .. d, o)
    end
  end
  return grp
end

--- Open the TUI window and run `cmd` (a squix argv list) in it.
local function run_in_tui(cmd)
  local focus = M.config.window.auto_focus ~= false
  local prev = vim.api.nvim_get_current_win()
  close_term()
  local win, buf = open_window(M.config.window)
  M.state.buf = buf
  M.state.win = win
  configure_terminal(buf)

  if focus then
    vim.api.nvim_create_autocmd("TermOpen", {
      once = true, buffer = buf,
      callback = function() vim.schedule(function() vim.cmd("startinsert") end) end,
    })
  end

  vim.fn.termopen(cmd, {
    on_exit = function(_, code)
      if code ~= 0 then return end
      vim.schedule(function()
        close_win_buf(win, buf)
        -- Only clear if still tracking this buffer (a newer TUI may have replaced it).
        if M.state.buf == buf then M.state.win, M.state.buf = nil, nil end
      end)
    end,
  })

  if not focus and vim.api.nvim_win_is_valid(prev) then
    pcall(vim.api.nvim_set_current_win, prev)
  end
end

--- Run SQL in the interactive squix TUI. With an explicit range (visual
--- selection, `:%`, `:a,b`) runs that; otherwise runs the cursor's paragraph.
function M.tui(opts)
  opts = opts or {}
  if not util.has_squix() then return end
  local sql = util.get_sql(sql_range(opts))
  if sql == "" then return end
  local cmd = { "squix", "run", sql }
  if M.config.hide_query then vim.list_extend(cmd, { "--hide-query-name", "--hide-query-sql" }) end
  run_in_tui(cmd)
end

--- `squix remove <name>` and notify.
local function remove_query(name)
  local r = vim.system({ "squix", "remove", name }):wait()
  if r.code == 0 then
    vim.notify("squix: removed " .. name, vim.log.levels.INFO)
  else
    util.err(vim.trim(r.stderr or "remove failed"))
  end
end

--- Browse the database's tables in the squix TUI (like :SquixRun; header hidden).
function M.tables()
  if not util.has_squix() then return end
  local cmd = { "squix", "tables" }
  if M.config.hide_query then vim.list_extend(cmd, { "--hide-query-name", "--hide-query-sql" }) end
  run_in_tui(cmd)
end

--- Pick a saved query from a list and call `on_choice(entry)` (nil if cancelled).
local function pick_query(prompt, on_choice)
  local out = vim.system({ "squix", "list", "queries", "--oneline" }, {
    stdout = true, stderr = true, env = { NO_COLOR = "1" },
  }):wait()
  if out.code ~= 0 then
    util.err(vim.trim(out.stderr or "failed to list queries"))
    return
  end
  local entries = util.parse_items(out.stdout, "no queries saved")
  if #entries == 0 then
    vim.notify("squix: no saved queries.", vim.log.levels.WARN)
    return
  end
  vim.ui.select(entries, {
    prompt = prompt,
    format_item = function(e) return e.label end,
  }, on_choice)
end

--- Run a saved query in the TUI: directly with opts.name, else pick from a list.
function M.query(opts)
  opts = opts or {}
  if not util.has_squix() then return end
  if opts.name and opts.name ~= "" then return run_in_tui({ "squix", "run", opts.name }) end
  pick_query("Squix query", function(choice)
    if choice then run_in_tui({ "squix", "run", choice.name }) end
  end)
end

--- Remove a saved query: directly with opts.name, else pick from a list.
function M.remove(opts)
  opts = opts or {}
  if not util.has_squix() then return end
  if opts.name and opts.name ~= "" then return remove_query(opts.name) end
  pick_query("Remove query", function(choice)
    if choice then remove_query(choice.name) end
  end)
end

--- Save the selected SQL (or the cursor's paragraph) as a named query via `squix add`.
function M.add(opts)
  opts = opts or {}
  if not util.has_squix() then return end
  local sql = util.get_sql(sql_range(opts))
  if sql == "" then
    vim.notify("squix: no SQL to save", vim.log.levels.WARN)
    return
  end
  local function save(name)
    name = vim.trim(name or "")
    if name == "" then return end
    vim.system({ "squix", "add", name, sql }, { stdout = true, stderr = true, env = { NO_COLOR = "1" } }, function(out)
      vim.schedule(function()
        if out.code == 0 then
          vim.notify("squix: " .. util.strip(vim.trim(out.stdout or "query added")), vim.log.levels.INFO)
        else
          util.err(vim.trim(out.stderr or out.stdout or "add failed"))
        end
      end)
    end)
  end
  if opts.name and opts.name ~= "" then save(opts.name)
  else vim.ui.input({ prompt = "Save query as: " }, save) end
end

--- Create a connection via `squix init` (type inferred from the conn string;
--- `$VAR` expanded for secrets).
function M.init(opts)
  opts = opts or {}
  if not util.has_squix() then return end

  vim.ui.input({ prompt = "Squix connection name: ", default = opts.name or "" }, function(name)
    name = vim.trim(name or "")
    if name == "" then return end
    vim.ui.input({
      prompt = "Connection string ($VAR expanded, type auto-inferred): ",
      default = opts.conn_string or "",
    }, function(cs)
      cs = vim.trim(cs or "")
      if cs == "" then return end
      vim.ui.input({ prompt = "Schema (optional, Enter to skip): ", default = opts.schema or "" }, function(schema)
        local args = { "squix", "init", "--name", name, "--conn-string", cs }
        schema = vim.trim(schema or "")
        if schema ~= "" then vim.list_extend(args, { "--schema", schema }) end
        vim.system(args, { stdout = true, stderr = true, env = { NO_COLOR = "1" } }, function(out)
          vim.schedule(function()
            if out.code == 0 then
              vim.notify("squix: " .. util.strip(vim.trim(out.stdout or "connection created")), vim.log.levels.INFO)
            else
              util.err(vim.trim(out.stderr or out.stdout or "init failed"))
            end
          end)
        end)
      end)
    end)
  end)
end

--- Show the active connection's type/schema, saved-query count, reachability.
function M.status()
  if not util.has_squix() then return end
  vim.system({ "squix", "status" }, { stdout = true, stderr = true, env = { NO_COLOR = "1" } }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        util.err(vim.trim(out.stderr or "status failed"))
        return
      end
      local msg = util.strip(out.stdout or "")
        :gsub("\n+", " · ")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
        :gsub(" ?·$", "")
      vim.notify("squix: " .. msg, vim.log.levels.INFO)
    end)
  end)
end

local function switch_to(name)
  local r = vim.system({ "squix", "switch", name }):wait()
  if r.code == 0 then
    vim.notify("squix: switched to " .. name, vim.log.levels.INFO)
  else
    util.err(vim.trim(r.stderr or "switch failed"))
  end
end

--- Switch connection: directly with opts.name, otherwise pick from a list.
function M.switch(opts)
  opts = opts or {}
  if not util.has_squix() then return end
  if opts.name and opts.name ~= "" then
    switch_to(opts.name)
    return
  end
  local out = vim.system({ "squix", "list", "connections" }, {
    stdout = true, stderr = true, env = { NO_COLOR = "1" },
  }):wait()
  if out.code ~= 0 then
    util.err(vim.trim(out.stderr or "failed to list connections"))
    return
  end
  local entries = util.parse_items(out.stdout, "no connections")
  if #entries == 0 then
    vim.notify("squix: no connections configured. Run :SquixInit first.", vim.log.levels.WARN)
    return
  end
  vim.ui.select(entries, {
    prompt = "Squix connection",
    format_item = function(e) return e.label end,
  }, function(choice)
    if choice then switch_to(choice.name) end
  end)
end

--- Completion candidate names from a `squix list <sub>` invocation.
local function complete_names(sub, skip_phrase)
  local out = vim.system(vim.list_extend({ "squix" }, sub), {
    stdout = true, stderr = true, env = { NO_COLOR = "1" },
  }):wait()
  if out.code ~= 0 then return {} end
  local names = {}
  for _, e in ipairs(util.parse_items(out.stdout, skip_phrase)) do
    table.insert(names, e.name)
  end
  return names
end

--- Hide the statusline while a squix TUI window is focused, restore it otherwise.
--- (nvim has no per-window statusline for splits, so this toggles the global option.)
local function register_hide_statusline()
  local saved
  vim.api.nvim_create_autocmd({ "TermOpen", "WinEnter", "BufEnter" }, {
    group = vim.api.nvim_create_augroup("SquixStatusline", { clear = true }),
    callback = function()
      local in_squix = M.state.buf
        and vim.api.nvim_buf_is_valid(M.state.buf)
        and vim.api.nvim_get_current_buf() == M.state.buf
      if in_squix then
        if vim.o.laststatus ~= 0 then saved = vim.o.laststatus end
        vim.o.laststatus = 0
      elseif saved ~= nil and vim.o.laststatus == 0 then
        vim.o.laststatus = saved
      end
    end,
  })
end

local function apply()
  vim.api.nvim_create_user_command("SquixRun", function(o)
    M.tui({ line1 = o.line1, line2 = o.line2, range = o.range })
  end, { range = true, desc = "Run SQL in the squix TUI" })

  vim.api.nvim_create_user_command("SquixInit", function() M.init() end,
    { desc = "Create a squix connection" })

  vim.api.nvim_create_user_command("SquixSwitch", function(o)
    M.switch({ name = o.args ~= "" and o.args or nil })
  end, {
    nargs = "?", desc = "Switch squix connection (picks if no name given)",
    complete = function() return complete_names({ "list", "connections" }, "no connections") end,
  })

  vim.api.nvim_create_user_command("SquixRunNamedQuery", function(o)
    M.query({ name = o.args ~= "" and o.args or nil })
  end, {
    nargs = "?", desc = "Run a saved query in the squix TUI (picks if no name given)",
    complete = function() return complete_names({ "list", "queries", "--oneline" }, "no queries saved") end,
  })

  vim.api.nvim_create_user_command("SquixRemove", function(o)
    M.remove({ name = o.args ~= "" and o.args or nil })
  end, {
    nargs = "?", desc = "Remove a saved query (picks if no name given)",
    complete = function() return complete_names({ "list", "queries", "--oneline" }, "no queries saved") end,
  })

  vim.api.nvim_create_user_command("SquixAdd", function(o)
    M.add({ name = o.args ~= "" and o.args or nil, line1 = o.line1, line2 = o.line2, range = o.range })
  end, { range = true, nargs = "?", desc = "Save selected/paragraph SQL as a named query" })

  vim.api.nvim_create_user_command("SquixStatus", function() M.status() end,
    { desc = "Show squix connection status" })

  vim.api.nvim_create_user_command("SquixTables", function() M.tables() end,
    { desc = "Browse database tables in the squix TUI" })

  local km = M.config.keymaps or {}
  if km.run then
    vim.keymap.set("n", km.run, "<cmd>SquixRun<cr>", { desc = "Squix: run SQL in TUI" })
    -- <Esc> first so '<,'> reflect THIS selection, not the previous one.
    vim.keymap.set("v", km.run, "<Esc><cmd>'<,'>SquixRun<cr>", { desc = "Squix: run SQL in TUI" })
  end
  if km.switch then
    vim.keymap.set("n", km.switch, "<cmd>SquixSwitch<cr>", { desc = "Squix: switch connection" })
  end
  if km.init then
    vim.keymap.set("n", km.init, "<cmd>SquixInit<cr>", { desc = "Squix: create connection" })
  end
  if km.status then
    vim.keymap.set("n", km.status, "<cmd>SquixStatus<cr>", { desc = "Squix: connection status" })
  end
  if km.tables then
    vim.keymap.set("n", km.tables, "<cmd>SquixTables<cr>", { desc = "Squix: browse tables" })
  end
  if km.run_named_query then
    vim.keymap.set("n", km.run_named_query, "<cmd>SquixRunNamedQuery<cr>", { desc = "Squix: run saved query" })
  end
  if km.add then
    vim.keymap.set("n", km.add, "<cmd>SquixAdd<cr>", { desc = "Squix: save SQL as query" })
    vim.keymap.set("v", km.add, "<Esc><cmd>'<,'>SquixAdd<cr>", { desc = "Squix: save SQL as query" })
  end

  if M.config.hide_statusline then register_hide_statusline() end
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  M._configured = true
  apply()
  if not M._path_checked then
    M._path_checked = true
    vim.schedule(function()
      if vim.fn.executable("squix") == 0 then
        vim.notify(
          "squix: 'squix' not on PATH — :Squix* commands will fail until squix is "
            .. "installed and visible to Neovim's PATH.",
          vim.log.levels.WARN
        )
      end
    end)
  end
  return M
end

return M
