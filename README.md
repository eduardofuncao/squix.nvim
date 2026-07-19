# squix.nvim

Run SQL from Neovim through [squix](https://github.com/eduardofuncao/squix) —
write a query, run it in the squix TUI, and stash reusable queries. Minimal and
zero-config (sensible defaults), configurable via `setup()`.

## Quick start

1. Install the [squix CLI](https://github.com/eduardofuncao/squix#quick-start).
2. `:SquixInit` — create a connection (prompts for name + connection string;
   see [connection-string examples](https://github.com/eduardofuncao/squix/blob/main/docs/databases.md)).
3. Write some SQL, then run it, stash it, and re-run it later:

```vim
:SquixRun              " run the SQL under the cursor (paragraph or selection) in the TUI
:SquixAdd              " save that SQL as a named query (prompts for a name)
:SquixRunNamedQuery    " pick and run a saved query
:SquixSwitch           " switch connection
```

That's the whole loop: write → run → save → re-run. No keymaps are bound by
default — see [Configuration](#configuration) to enable `<leader>s*` shortcuts.

## Requirements

- Neovim **0.10+** (uses `vim.system`, `vim.ui.select`)
- The **squix** CLI installed and on `PATH` ([install](https://github.com/eduardofuncao/squix#quick-start))
- At least one connection configured (`:SquixInit` from within Neovim, or `squix init` on the CLI)

## Install

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ "eduardofuncao/squix.nvim", opts = {} }
```

### [vim.pack](https://neovim.io/doc/user/lua.html#vim.pack) — Neovim ≥ 0.12 native

```lua
vim.pack.add({ "eduardofuncao/squix.nvim" })
require("squix").setup({})
```

## Try without installing

Clone the repo and load it straight from Neovim (no plugin manager needed; just
needs the `squix` CLI on `PATH`):

```fish
git clone https://github.com/eduardofuncao/squix.nvim
cd squix.nvim
nvim --cmd "set rtp^=$PWD" -c "lua require('squix').setup({})"
```

All `:Squix*` commands are available. Add a `window = { position = "float" }` to
that `setup()` call to try the centered float.

## Commands

| Command | Description |
| --- | --- |
| `:SquixRun` | Run SQL in the squix TUI (split or centered float — see `window.position`). In normal mode runs the cursor's paragraph (blank-line-delimited block); a visual selection / range / `:%` runs exactly that. |
| `:SquixRunNamedQuery [name]` | Run a saved query in the TUI. With a name, runs it directly; without, picks from your stashed queries. Tab-completes query names. |
| `:SquixAdd [name]` | Save the selected SQL (or the cursor's paragraph) as a named query (`squix add`). Range-aware like `:SquixRun`. |
| `:SquixRemove [name]` | Remove a saved query. With a name, removes it directly; without, picks from a list. Tab-completes query names. |
| `:SquixInit` | Create a new connection (prompts for name, connection string, optional schema). Db type is inferred from the connection string; `$VAR` is expanded for secrets. |
| `:SquixSwitch [name]` | Switch to a connection. With a name, switches directly; without, picks from a list. Tab-completes connection names. |
| `:SquixStatus` | Show the active connection's type/schema, saved-query count, and reachability. |
| `:SquixTables` | Browse the database's tables in the squix TUI (split or float, header hidden like `:SquixRun`). Press `Enter` on a table to query it. |

Examples:

```vim
:.SquixRun                  " run current line in the TUI
:'<,'>SquixRun              " run visual selection in the TUI
:SquixSwitch production     " switch directly, no picker
:'<,'>SquixAdd top_clients  " save the selection as a named query
```

## Configuration

```lua
require("squix").setup({
  hide_query = true,          -- :SquixRun hides query name + SQL (already shown in the editor)
  term_keymaps = true,        -- in-TUI <C-w>hjkl window navigation; false sends keys raw to the TUI
  hide_statusline = true,     -- set laststatus=0 while the squix TUI is focused (splits have no per-window statusline)
  window = {
    position        = "botright", -- "botright" | "topleft" | "vertical" | "float"
    split_ratio     = 0.4,        -- fraction of the editor for split positions
    auto_focus      = true,       -- focus (and enter) the TUI window when it opens; false opens it in the background
    float = {                     -- only when position = "float"
      width = "80%", height = "80%", row = "center", col = "center",
      relative = "editor", border = "rounded",
    },
  },
  keymaps = {                 -- none mapped by default; set any to a key to enable
    run             = "<leader>st", -- :SquixRun            (normal + visual)
    run_named_query = "<leader>sq", -- :SquixRunNamedQuery  (normal)
    add             = "<leader>sa", -- :SquixAdd            (normal + visual)
    switch          = "<leader>ss", -- :SquixSwitch         (normal)
    init            = "<leader>si", -- :SquixInit           (normal)
    status          = "<leader>sS", -- :SquixStatus         (normal)
    tables          = "<leader>sT", -- :SquixTables         (normal)
  },
})
```

## License

MIT, inherited from the squix repository.
