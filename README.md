<div align="center">
   <h1>
      <img width="auto" height="48" alt="squix.nvim mascot" src="https://github.com/user-attachments/assets/12c80b15-e6a9-4417-927c-81dea11d8c61" />
      squix.nvim
      <img width="auto" height="36" alt="image" src="https://github.com/user-attachments/assets/c128f28f-dd10-4213-9915-dedafe7ae831" />
   </h1>
   <img width="967" height="682" alt="image" src="https://github.com/user-attachments/assets/0e81562c-7249-4875-8f70-0fbe2e2be88e" />
   
   Run SQL from Neovim with [squix](https://github.com/eduardofuncao/squix): 
   write a query, run it and save it for later. Navigate results with vim bindings 
</div>


## Quick start

1. Install the [squix CLI](https://github.com/eduardofuncao/squix#installation).
2. Install the [squix.nvim plugin](#install) 
3. Run `:SquixInit` to create a connection from a database connection string (prompts for name + connstring.
   see [connection-string examples for different database engines](https://github.com/eduardofuncao/squix/blob/main/docs/databases.md)).
4. Write some SQL, then run it, stash it, and re-run it later:

```vim
:SquixRun              " run the SQL under the cursor (paragraph or selection) in the TUI
:SquixAdd              " save that SQL as a named query (prompts for a name)
:SquixRunNamedQuery    " pick and run a saved query
:SquixSwitch           " switch  database connection
```
5. After the query results window opens, you can traverse it using vim bindings: `hjkl`, `0/$`, `gg/G`, `<C-D>/<C-U>` for navigation; `v/V`, `y` and `x` for visual selection, copying and exporting results; `/` for searching results contents (`n/N` for next/prev) and `f` for searching columns names (`;/,` for next/prev); `q` to close it. Press `H` for the full shortcut list

<img width="867" height="300" alt="image" src="https://github.com/user-attachments/assets/5c776060-6e57-483f-8942-56c99fadad06" />

5. It is also possible to run update (`u`) and delete commands(`D`), as well as changing the ran SQL (`e`). For these keybinds, squix will open a buffer preloaded with the SQL statement, and you can save and quit (`:wq`) to run it, or quit without saving(`:q`) to cancel it

That's the main loop: write → run → save → re-run. 
> No keymaps are bound by default. See [Plugin Configuration](#plugin-configuration) to enable the recommended `<leader>s*` shortcuts.

## Requirements

- Neovim **0.10+** (uses `vim.system`, `vim.ui.select`)
- The **squix** CLI installed and on `PATH` ([install](https://github.com/eduardofuncao/squix#quick-start))
- At least one database connection configured (`:SquixInit` from within Neovim, or `squix init` on the CLI)

## Install

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ "eduardofuncao/squix.nvim", opts = {} }
```

### [vim.pack](https://neovim.io/doc/user/lua.html#vim.pack) Neovim ≥ 0.12 native

```lua
vim.pack.add({ "eduardofuncao/squix.nvim" })
require("squix").setup({})
```

### Try without installing

Clone the repo and load it straight from Neovim (no plugin manager needed; just
needs the `squix` CLI on `PATH`):

```fish
git clone https://github.com/eduardofuncao/squix.nvim
cd squix.nvim
nvim --cmd "set rtp^=$PWD" -c "lua require('squix').setup({})"
```

> try adding a `window = { position = "float" }` to
that `setup()` call to try the centered float.

## All Commands

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

## Plugin Configuration

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

## Squix Configuration
All database connections and squix configuration options are stored in `$HOME/.config/squix/config.yaml`. See [squix configuration doc](https://github.com/eduardofuncao/squix/blob/main/docs/configuration.md) for more options

---

<div align="center">
Made with 🐿️ by [@eduardofuncao](https://github.com/eduardofuncao)
</div>

