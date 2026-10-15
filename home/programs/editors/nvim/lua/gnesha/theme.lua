local M = {}

local fallback = {
  base00 = "#050805",
  base01 = "#0b100c",
  base02 = "#121a13",
  base03 = "#1c2b1f",
  base04 = "#2b412f",
  base05 = "#a8f5c9",
  base06 = "#d3ffdf",
  base07 = "#f0fff2",
  base08 = "#ff2e57",
  base09 = "#ffa53d",
  base0A = "#d19a66",
  base0B = "#00ff9c",
  base0C = "#35ffcf",
  base0D = "#53aaff",
  base0E = "#c14dff",
  base0F = "#2e7a4a",
}

local function load_palette_file(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end

  local ok, palette = pcall(dofile, path)
  if ok and type(palette) == "table" and palette.base00 then
    return palette
  end

  return nil
end

local function palette()
  local runtime = load_palette_file(vim.fn.expand("~/.config/gnesha/nvim-theme.lua"))
  if runtime then
    return runtime
  end

  local generated = load_palette_file(vim.fn.expand("~/.config/gnesha/nvim-default-theme.lua"))
  return generated or fallback
end

local function set(group, spec)
  vim.api.nvim_set_hl(0, group, spec)
end

local function link(group, target)
  set(group, { link = target })
end

function M.apply(p)
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end

  vim.o.background = "dark"
  vim.g.colors_name = "gnesha-base16"

  set("Normal", { fg = p.base05, bg = p.base00 })
  set("NormalFloat", { fg = p.base05, bg = p.base01 })
  set("FloatBorder", { fg = p.base0B, bg = p.base01 })
  set("Cursor", { fg = p.base00, bg = p.base05 })
  set("CursorLine", { bg = p.base01 })
  set("CursorLineNr", { fg = p.base0B, bold = true })
  set("LineNr", { fg = p.base03 })
  set("SignColumn", { fg = p.base04, bg = p.base00 })
  set("Visual", { bg = p.base02 })
  set("Search", { fg = p.base00, bg = p.base0A })
  set("IncSearch", { fg = p.base00, bg = p.base0B })
  set("Substitute", { fg = p.base00, bg = p.base0A })
  set("Pmenu", { fg = p.base05, bg = p.base01 })
  set("PmenuSel", { fg = p.base00, bg = p.base0B })
  set("StatusLine", { fg = p.base05, bg = p.base01 })
  set("StatusLineNC", { fg = p.base04, bg = p.base01 })
  set("WinSeparator", { fg = p.base02, bg = p.base00 })
  set("VertSplit", { fg = p.base02, bg = p.base00 })
  set("Directory", { fg = p.base0D })
  set("Title", { fg = p.base0B, bold = true })
  set("ModeMsg", { fg = p.base0B, bold = true })
  set("MoreMsg", { fg = p.base0B })
  set("Question", { fg = p.base0B })
  set("ErrorMsg", { fg = p.base08 })
  set("WarningMsg", { fg = p.base0A })
  set("MatchParen", { fg = p.base0A, bold = true, underline = true })

  set("Comment", { fg = p.base03, italic = true })
  set("Constant", { fg = p.base09 })
  set("String", { fg = p.base0B })
  set("Character", { fg = p.base0C })
  set("Number", { fg = p.base09 })
  set("Boolean", { fg = p.base09 })
  set("Float", { fg = p.base09 })
  set("Identifier", { fg = p.base08 })
  set("Function", { fg = p.base0D })
  set("Statement", { fg = p.base0E })
  set("Conditional", { fg = p.base0E })
  set("Repeat", { fg = p.base0E })
  set("Label", { fg = p.base0E })
  set("Operator", { fg = p.base0C })
  set("Keyword", { fg = p.base0E })
  set("Exception", { fg = p.base08 })
  set("PreProc", { fg = p.base0A })
  set("Include", { fg = p.base0D })
  set("Define", { fg = p.base0E })
  set("Macro", { fg = p.base0D })
  set("Type", { fg = p.base0A })
  set("StorageClass", { fg = p.base0E })
  set("Structure", { fg = p.base0A })
  set("Special", { fg = p.base0C })
  set("SpecialComment", { fg = p.base04 })
  set("Todo", { fg = p.base0A, bg = p.base01, bold = true })
  set("Error", { fg = p.base08 })

  set("DiagnosticError", { fg = p.base08 })
  set("DiagnosticWarn", { fg = p.base0A })
  set("DiagnosticInfo", { fg = p.base0C })
  set("DiagnosticHint", { fg = p.base0D })
  set("DiagnosticVirtualTextError", { fg = p.base08 })
  set("DiagnosticVirtualTextWarn", { fg = p.base0A })
  set("DiagnosticVirtualTextInfo", { fg = p.base0C })
  set("DiagnosticVirtualTextHint", { fg = p.base0D })

  -- Treesitter and common plugin groups.
  link("@comment", "Comment")
  link("@constant", "Constant")
  link("@string", "String")
  link("@number", "Number")
  link("@boolean", "Boolean")
  link("@function", "Function")
  link("@function.call", "Function")
  link("@keyword", "Keyword")
  link("@operator", "Operator")
  link("@type", "Type")
  link("@variable", "Identifier")
  link("NvimTreeNormal", "Normal")
  link("NvimTreeFolderName", "Directory")
  link("TelescopeNormal", "NormalFloat")
  link("TelescopeBorder", "FloatBorder")
  link("CmpItemAbbrMatch", "Function")
  link("CmpItemKind", "Type")
end

function M.reload()
  M.apply(palette())
end

function M.setup()
  M.reload()
  vim.api.nvim_create_user_command("GneshaThemeReload", M.reload, {
    desc = "Reload the Gnesha Base16 theme",
  })
end

return M
