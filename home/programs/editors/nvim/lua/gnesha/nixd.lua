local M = {}

local function flake_root()
  return vim.fs.root(0, { "flake.nix" })
end

local function flake_expression(root)
  return string.format("(builtins.getFlake %q)", root)
end

local function options_expression(flake, configuration_set, documentation)
  -- This repository currently exposes one host and one Home Manager profile.
  -- Selecting the first discovered output avoids hardcoding either name.
  return string.format(
    "(let flake = %s; configuration = builtins.getAttr (builtins.head (builtins.attrNames flake.%s)) flake.%s; "
      .. "in import %s { lib = flake.inputs.nixpkgs.lib; options = configuration.options; })",
    flake,
    configuration_set,
    configuration_set,
    documentation
  )
end

function M.settings()
  local settings = {
    formatting = {
      command = { "nixfmt" },
    },
  }

  local root = flake_root()
  if not root then
    return settings
  end

  local helper = assert(vim.api.nvim_get_runtime_file("lua/gnesha/nixd-options.nix", false)[1],
    "nixd option documentation helper is missing")
  local documentation = vim.json.encode(helper):gsub("%$%{", "\\${")
  local flake = flake_expression(root)
  settings.nixpkgs = {
    expr = string.format("import %s.inputs.nixpkgs { }", flake),
  }
  settings.options = {
    nixos = {
      expr = options_expression(flake, "nixosConfigurations", documentation),
    },
    home_manager = {
      expr = options_expression(flake, "homeConfigurations", documentation),
    },
  }

  return settings
end

return M
