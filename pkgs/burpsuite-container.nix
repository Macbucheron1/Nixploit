{
  lib,
  stdenv,
  fetchurl,
  jdk,
  makeWrapper,
  makeDesktopItem,
  unzip,
  alsa-lib,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  gtk3-x11,
  libcanberra-gtk3,
  libdrm,
  udev,
  libxkbcommon,
  libgbm,
  libglvnd,
  nspr,
  nss,
  pango,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  proEdition ? false,
}:

let
  version = "2026.3.1";

  product =
    if proEdition then
      {
        productName = "pro";
        productDesktop = "Burp Suite Professional Edition";
        hash = "sha256-jRVRvqFRsRO+vbEoV35bX4vi9XEYl737L0umt61ACtk=";
      }
    else
      {
        productName = "community";
        productDesktop = "Burp Suite Community Edition";
        hash = "sha256-wjXzFXE+cIHw8tXuitsN4emH5varOTWQxiohwFGKZvc=";
      };

  src = fetchurl {
    name = "burpsuite.jar";
    urls = [
      "https://portswigger-cdn.net/burp/releases/download?product=${product.productName}&version=${version}&type=Jar"
      "https://portswigger.net/burp/releases/download?product=${product.productName}&version=${version}&type=Jar"
      "https://web.archive.org/web/https://portswigger.net/burp/releases/download?product=${product.productName}&version=${version}&type=Jar"
    ];
    hash = product.hash;
  };

  runtimeLibs = [
    alsa-lib at-spi2-core cairo cups dbus expat glib gtk3 gtk3-x11
    libcanberra-gtk3 libdrm udev libxkbcommon libgbm libglvnd
    nspr nss pango libx11 libxcb libxcomposite libxdamage libxext
    libxfixes libxrandr
  ];

  desktopItem = makeDesktopItem {
    name = "burpsuite";
    exec = "burpsuite";
    icon = "burpsuite";
    desktopName = product.productDesktop;
    comment = "Integrated platform for performing security testing of web applications";
    categories = [ "Development" "Security" "System" ];
  };
in
stdenv.mkDerivation rec {
  pname = "burpsuite-container";
  inherit version;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper unzip ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/java $out/share/icons/hicolor/64x64/apps $out/share
    cp ${src} $out/share/java/burpsuite.jar
    ${lib.getBin unzip}/bin/unzip -p ${src} resources/Media/icon64${product.productName}.png > \
      $out/share/icons/hicolor/64x64/apps/burpsuite.png
    cp -r ${desktopItem}/share/applications $out/share/

    makeWrapper ${jdk}/bin/java $out/bin/burpsuite \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --set-default _JAVA_AWT_WM_NONREPARENTING 1 \
      --add-flags "-jar $out/share/java/burpsuite.jar"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Burp Suite launcher without buildFHSEnv, intended for container usage";
    homepage = "https://portswigger.net/burp/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
    platforms = platforms.linux;
    mainProgram = "burpsuite";
  };
}

