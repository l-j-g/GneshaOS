{ inputs, pkgs, ... }:

let
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.nix-skills.homeManagerModules.default ];

  # OpenCode also discovers the shared Codex user skill directory.
  programs.nix-skills = {
    enable = true;
    agents = [ "codex" ];
  };

  home.packages = [
    agents.codex
    agents.opencode
  ];
}
