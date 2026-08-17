local M = {}

function M.setup()
  local ok, project = pcall(require, "project_nvim")
  if not ok then
    return
  end

  project.setup({
    detection_methods = { "lsp", "pattern" },
    patterns = { ".git", "flake.nix", "pyproject.toml", "package.json", "Cargo.toml" },
    silent_chdir = true,
  })
end

return M
