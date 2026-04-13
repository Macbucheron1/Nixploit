{ username, pkgs, lib, config, ... }:
let 
  cfg = config.my;
  finalHistory = pkgs.concatText "pentest-history" (lib.attrValues cfg.histories);

  myCustomPkgs = import ../pkgs { inherit pkgs; };

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
    shellAliases = { 
      c = "clear"; 
      l = "${pkgs.eza}/bin/eza -lah --git --icons=always"; 
      ll = "${pkgs.eza}/bin/eza -lah --git --icons=always";
      ls = "${pkgs.eza}/bin/eza -G --icons";
      tree = "${pkgs.eza}/bin/eza -T --icons";
    };
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

  programs.codex = {
    enable = true;

    settings.mcp_servers = {
      nixos = {
        type = "stdio";
        command = "nix";
        args = [ "run" "github:utensils/mcp-nixos" "--" ];
      };

      wiremcp = {
        type = "stdio";
        command = "${myCustomPkgs.wiremcp}/bin/wiremcp";
      };

      burp = {
        type = "stdio";
        command = "${pkgs.mcp-proxy}/bin/mcp-proxy";
        args = [ "http://127.0.0.1:9876" ];
      };
    };

    };
  home.file.".bash_history".source = finalHistory;

  programs.zellij.enable = true;
}
