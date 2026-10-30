local M = {}

function M.setup()
  local cmp = require("cmp")
  local luasnip = require("luasnip")

  require("luasnip.loaders.from_vscode").lazy_load()

  cmp.setup({
    window = {
      completion = cmp.config.window.bordered({ scrollbar = true }),
      documentation = cmp.config.window.bordered({ max_width = 80, max_height = 24 }),
    },
    formatting = {
      fields = { "abbr", "kind", "menu" },
      format = function(entry, item)
        local labels = { nvim_lsp = "LSP", luasnip = "Snippet", path = "Path", buffer = "Buffer" }
        item.menu = "[" .. (labels[entry.source.name] or entry.source.name) .. "]"
        if vim.fn.strdisplaywidth(item.abbr) > 50 then
          item.abbr = vim.fn.strcharpart(item.abbr, 0, 47) .. "..."
        end
        return item
      end,
    },
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ["<C-d>"] = cmp.mapping.scroll_docs(-4),
      ["<C-f>"] = cmp.mapping.scroll_docs(4),
      ["<C-e>"] = cmp.mapping.abort(),
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<CR>"] = cmp.mapping.confirm({ select = true }),
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { "i", "s" }),
    }),
    sources = {
      { name = "nvim_lsp" },
      { name = "luasnip" },
      { name = "path" },
      { name = "buffer" },
    },
  })
end

return M
