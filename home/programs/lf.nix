{
  ...
}:

let
  lfPreviewer = ./scripts/lf/preview;
in
{
  programs.lf = {
    enable = true;
    previewer.source = lfPreviewer;
    commands = {
      # Reset the preview position whenever the selected file changes.
      on-select = "set user_preview_offset 1";
      scroll-preview = ''&{{
        offset=$((lf_user_preview_offset + $1))
        [ "$offset" -lt 1 ] && offset=1
        lf -remote "send $id :set user_preview_offset $offset; set preview true"
      }}'';
    };
    keybindings = {
      "<a-j>" = "scroll-preview 5";
      "<a-k>" = "scroll-preview -5";
    };
    extraConfig = ''
      set user_preview_offset 1
    '';
    settings = {
      hidden = true;
      number = true;
      ratios = [
        1
        2
        3
      ];
    };
  };
}
