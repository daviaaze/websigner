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
    mkdir -p $out/lib/mozilla/native-messaging-hosts
    mkdir -p $out/share/mozilla/native-messaging-hosts
    
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
    for file in $out/lib/mozilla/native-messaging-hosts/*.json $out/share/mozilla/native-messaging-hosts/*.json; do
      if [ -f "$file" ]; then
        sed -i "s|/opt/softplan-websigner/websigner|$out/opt/softplan-websigner/websigner|g" "$file"
      fi
    done
  '';

  meta = with lib; {
    description = "WebSigner - Digital signature application by Softplan";
    homepage = "https://www.softplan.com.br/";
    license = licenses.unfree; # Assuming it's proprietary software
    platforms = platforms.linux;
    maintainers = [ ]; # Add your name here if you want
    
    # Since this is a .deb package, it's likely x86_64 only
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
} 