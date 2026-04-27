{
  # Define the path where the image is expecting the files
  # For GPU runtime assets mounted from the host
  runtime = {
    root = "/mnt/runtime";

    gpu = {
      root = "/mnt/runtime/gpu";
      libDir = "/mnt/runtime/gpu/lib";
      openclVendorDir = "/mnt/runtime/gpu/OpenCL/vendors";
    };
  };
}
