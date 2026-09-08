{
  ...
}:

{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    mouse = true;
    keyMode = "vi";
    escapeTime = 0;
    focusEvents = true;
    historyLimit = 50000;
    extraConfig = ''
      set -g renumber-windows on
      set -g set-clipboard on
      set -as terminal-features ",*:RGB"
    '';
  };
}
