-- squix.nvim — zero-config entry point. Override defaults with require("squix").setup({...}).
local squix = require("squix")
if not squix._configured then squix.setup() end
