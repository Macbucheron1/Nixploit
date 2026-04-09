{ username ? "user", pkgs, lib, config, ... }:
let 
  cfg = config.my;
  finalHistory = pkgs.concatText "pentest-history" (lib.attrValues cfg.histories);

  fzfTab = pkgs.nur.repos.hexadecimalDinosaur.fzf-tab-completion;
in
{
  programs.bash = {
    enable = true;
    historyFile = "/home/${username}/.bash_history";
    bashrcExtra = ''
      # vim motion in the shell
      set -o vi

      # Allow fzf autocompletion using alt tab
      source ${fzfTab}/bash/fzf-bash-completion.sh
      bind -x '"\e\t": fzf_bash_completion'
    '';
  };

  # Show a different cursor when in normal mode in the shell
  programs.readline = {
    enable = true;
    includeSystemConfig = true;
    variables = {
      editing-mode = "vi";
      show-mode-in-prompt = true;
      vi-ins-mode-string = ''\1\e[6 q\2'';
      vi-cmd-mode-string = ''\1\e[2 q\2'';
    };
  };

  programs.fzf = {
    enable = true;
    # Allow to search through the history using fzf
    enableBashIntegration = true;
  };

  home.file.".bash_history".source = finalHistory;

  programs.zellij.enable = true;
}
