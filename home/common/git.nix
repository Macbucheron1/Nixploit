{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
