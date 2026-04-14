{ pkgs, ... }:
let 
  myCustomPkgs = import ../../pkgs { inherit pkgs; };
in
{
  programs.codex = {
    enable = true;

    settings.mcp_servers = {
      github = {
        type = "http";
        url = "https://api.githubcopilot.com/mcp/";
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
}
