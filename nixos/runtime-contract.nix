{
  # Define the path where the image is expecting the files
  # For GPU & GUI (wayland & x11)
  runtime = {
    root = "/mnt/runtime";

    gui = {
      root = "/mnt/runtime/gui";
      waylandSocket = "/mnt/runtime/gui/wayland-0";
      x11SocketDir = "/mnt/runtime/gui/.X11-unix";
      xauthorityFile = "/mnt/runtime/gui/.Xauthority";
    };

    gpu = {
      root = "/mnt/runtime/gpu";
      libDir = "/mnt/runtime/gpu/lib";
      openclVendorDir = "/mnt/runtime/gpu/OpenCL/vendors";
    };
  };
}
