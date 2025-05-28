{
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  lib,
  glibc,
  gcc-unwrapped,
  zlib,
  openssl,
  curl,
  libxcrypt-legacy,
  xorg,
  fontconfig,
  freetype,
  libGL,
  libICE,
  libSM,
  libXext,
  libXi,
  libXrandr,
  libXrender,
  libXtst,
  libXxf86vm,
  libdrm,
  mesa,
  icu,
  krb5,
  lttng-ust,
  numactl,
  systemd,
}:

stdenv.mkDerivation rec {
  pname = "websigner";
  version = "2.12.1";

  src = fetchurl {
    url = "https://websigner.softplan.com.br/Downloads/${version}/setup-deb-64";
    sha256 = "sha256-Xaj9NvE3H1K7rr7edfreGSjwnP8t1gW42lZjxtpQU3k=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    glibc
    gcc-unwrapped.lib
    zlib
    openssl
    curl
    libxcrypt-legacy
    # X11 and GUI dependencies
    xorg.libX11
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libXxf86vm
    xorg.libxcb
    xorg.libXext
    xorg.libXScrnSaver
    fontconfig
    freetype
    libGL
    libICE
    libSM
    libdrm
    mesa
    icu
    krb5
    lttng-ust
    numactl
    systemd
  ];

  # Use dpkg to extract the .deb file
  unpackPhase = ''
    runHook preUnpack
    
    # Extract the .deb file using dpkg-deb
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-owner
    
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    
    # Create output directories
    mkdir -p $out/opt/softplan-websigner
    mkdir -p $out/bin
    
    # Mozilla/Firefox native messaging hosts
    mkdir -p $out/lib/mozilla/native-messaging-hosts
    mkdir -p $out/share/mozilla/native-messaging-hosts
    
    # Chrome/Chromium native messaging hosts
    mkdir -p $out/etc/chromium/native-messaging-hosts
    mkdir -p $out/etc/chrome/native-messaging-hosts
    mkdir -p $out/etc/opt/chrome/native-messaging-hosts
    
    # Copy the main application
    cp -r opt/softplan-websigner/* $out/opt/softplan-websigner/
    
    # Copy Mozilla native messaging host configurations
    if [ -d usr/lib/mozilla/native-messaging-hosts ]; then
      cp -r usr/lib/mozilla/native-messaging-hosts/* $out/lib/mozilla/native-messaging-hosts/
    fi
    
    if [ -d usr/lib64/mozilla/native-messaging-hosts ]; then
      cp -r usr/lib64/mozilla/native-messaging-hosts/* $out/lib/mozilla/native-messaging-hosts/
    fi
    
    if [ -d usr/share/mozilla/native-messaging-hosts ]; then
      cp -r usr/share/mozilla/native-messaging-hosts/* $out/share/mozilla/native-messaging-hosts/
    fi
    
    # Copy Chrome/Chromium native messaging host configurations
    # Chrome looks in /etc/chromium/native-messaging-hosts and /etc/opt/chrome/native-messaging-hosts
    for json_file in $out/opt/softplan-websigner/*.json; do
      if [ -f "$json_file" ]; then
        cp "$json_file" $out/etc/chromium/native-messaging-hosts/
        cp "$json_file" $out/etc/chrome/native-messaging-hosts/
        cp "$json_file" $out/etc/opt/chrome/native-messaging-hosts/
      fi
    done
    
    # Make the main executable accessible from PATH
    makeWrapper $out/opt/softplan-websigner/websigner $out/bin/websigner \
      --set LD_LIBRARY_PATH "${lib.makeLibraryPath buildInputs}" \
      --prefix PATH : "${lib.makeBinPath [ xorg.xrandr ]}"
    
    # Fix permissions on the main executable
    chmod +x $out/opt/softplan-websigner/websigner
    
    runHook postInstall
  '';

  # Fix the native messaging host JSON files to point to the correct path
  postInstall = ''
    # Update the native messaging host configuration files to point to our installation
    for dir in  opt/softplan-websigner lib/mozilla/native-messaging-hosts share/mozilla/native-messaging-hosts etc/chromium/native-messaging-hosts etc/chrome/native-messaging-hosts etc/opt/chrome/native-messaging-hosts; do
      for file in $out/$dir/*.json; do
        if [ -f "$file" ]; then
          sed -i "s|/opt/softplan-websigner/websigner|$out/opt/softplan-websigner/websigner|g" "$file"
        fi
      done
    done
  '';

  # Provide passthru for easy access to native messaging host files
  passthru = {
    # For NixOS modules that need to install native messaging hosts
    nativeMessagingHosts = {
      firefox = "$out/lib/mozilla/native-messaging-hosts";
      chrome = "$out/etc/chromium/native-messaging-hosts";
      chromium = "$out/etc/chromium/native-messaging-hosts";
    };
  };

  meta = with lib; {
    description = "WebSigner - Digital signature application by Softplan";
    homepage = "https://www.softplan.com.br/";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [ ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
} 