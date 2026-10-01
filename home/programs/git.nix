# Git client configuration and the GitHub CLI.

{
  variables,
  ...
}:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = variables.gitUserName;
        email = variables.gitUserEmail;
      };
      init.defaultBranch = "main";
      core.autocrlf = "input";
      push.autoSetupRemote = true;
    };
  };

  programs.gh.enable = true;
}
