{ pkgs, lib }:
name: files:
pkgs.writeText name (lib.concatMapStrings (file:
  let
    content = builtins.readFile file;
  in
  content + lib.optionalString (!lib.hasSuffix "\n" content) "\n"
) files)
