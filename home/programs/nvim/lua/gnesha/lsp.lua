local capabilities = require("cmp_nvim_lsp").default_capabilities()
local nixd = require("gnesha.nixd")

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
  callback = function(ev)
    local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, silent = true, desc = desc })
    end

    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gr", vim.lsp.buf.references, "References")
    map("K", vim.lsp.buf.hover, "Hover documentation")
    map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("<leader>lf", vim.lsp.buf.format, "Format buffer")
    map("[d", vim.diagnostic.goto_prev, "Previous diagnostic")
    map("]d", vim.diagnostic.goto_next, "Next diagnostic")
  end,
})

vim.lsp.config("nixd", {
  capabilities = capabilities,
  settings = {
    nixd = nixd.settings(),
  },
})

vim.lsp.config("bashls", {
  capabilities = capabilities,
})

vim.lsp.enable("nixd")
vim.lsp.enable("bashls")
