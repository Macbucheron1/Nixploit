{ pkgs, lib, ... }:
{
  environment.systemPackages = lib.mkAfter (with pkgs; [
    ocl-icd
    clinfo
  ]);

  environment.etc."OpenCL/vendors/nvidia.icd".text =
    "/mnt/opengl-driver/lib/libnvidia-opencl.so.1\n";

  environment.sessionVariables = {
    OPENCL_VENDOR_PATH = "/etc/OpenCL/vendors";
    LD_LIBRARY_PATH = "/mnt/opengl-driver/lib";
  };
}
