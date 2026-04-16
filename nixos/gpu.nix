{ pkgs, lib, runtimeContract, ... }:
let
  inherit (runtimeContract.runtime) gpu;
in
{
  hardware.graphics.enable = true;

  environment.systemPackages = lib.mkAfter (with pkgs; [
    ocl-icd
    clinfo
  ]);

  # When entering a shell, export all GPU related variable
  environment.loginShellInit = ''
    if [ -d ${gpu.libDir} ]; then
      export LD_LIBRARY_PATH="${gpu.libDir}''${LD_LIBRARY_PATH:+:''${LD_LIBRARY_PATH}}"
    fi

    if [ -d ${gpu.openclVendorDir} ]; then
      export OPENCL_VENDOR_PATH="${gpu.openclVendorDir}"
    fi
  '';
}
