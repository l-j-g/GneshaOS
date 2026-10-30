local M = {}

function M.show(option_name)
  local root = vim.fs.root(0, { "flake.nix" })
  if not root then
    vim.notify("Open a file inside a flake first", vim.log.levels.WARN)
    return
  end
  vim.ui.select({ "NixOS", "Home Manager" }, { prompt = "Option configuration:" }, function(scope)
    if not scope then
      return
    end
    local function lookup(name)
      if not name or name == "" then
        return
      end
      -- Attribute names are passed as data, never interpolated into Nix or shell code.
      local evaluator = vim.api.nvim_get_runtime_file("lua/gnesha/option-info.nix", false)[1]
      if not evaluator then
        vim.notify("Nix option evaluator is missing from runtimepath", vim.log.levels.ERROR)
        return
      end
      vim.notify("Evaluating " .. name .. " from the saved flake…")
      vim.system({
        "nix-instantiate", "--eval", "--strict", "--json", "--option", "allow-import-from-derivation", "false", evaluator,
        "--argstr", "flakePath", root,
        "--argstr", "configurationSet", scope == "NixOS" and "nixosConfigurations" or "homeConfigurations",
        "--argstr", "optionName", name,
      }, { text = true, timeout = 60000 }, vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          vim.notify("Option lookup failed: " .. result.stderr, vim.log.levels.ERROR)
          return
        end
        local ok, info = pcall(vim.json.decode, result.stdout)
        if not ok then
          vim.notify("Option lookup returned invalid JSON", vim.log.levels.ERROR)
          return
        end
        local lines = {
          "# " .. name,
          "", scope .. " · " .. info.configuration,
          "", "Type: " .. info.type,
          "", "## Default", "```", info.default, "```",
          "", "## Evaluated value (saved flake)", "```json", info.current, "```",
          "", "Unsaved edits are excluded. This is not the running system's value.",
        }
        -- Values and defaultText can contain newlines.
        lines = vim.split(table.concat(lines, "\n"), "\n", { plain = true })
        vim.lsp.util.open_floating_preview(lines, "markdown", {
          border = "rounded", max_width = 90, max_height = 30, focus = true,
        })
      end))
    end
    if option_name and option_name ~= "" then
      lookup(option_name)
    else
      vim.ui.input({ prompt = "Full option path (e.g. programs.git.enable): " }, lookup)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("NixOption", function(args)
    M.show(args.args)
  end, { nargs = "?", desc = "Show a Nix option's default and evaluated flake value" })
end

return M
