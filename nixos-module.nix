# NixOS module for WebSigner
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.websigner;
in

{
  options.programs.websigner = {
    enable = mkEnableOption "WebSigner - Digital signature application by Softplan";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./websigner.nix { };
      defaultText = literalExpression "pkgs.callPackage ./websigner.nix { }";
      description = "The WebSigner package to use.";
    };

    enableSmartCardSupport = mkOption {
      type = types.bool;
      default = true;
      description = "Enable smart card support for PKCS#11 certificates.";
    };
  };

  config = mkIf cfg.enable {
    # Install WebSigner package and smart card tools
    environment.systemPackages = [ cfg.package ] ++ 
      (optionals cfg.enableSmartCardSupport [
        pkgs.opensc
        pkgs.pcsclite
        pkgs.ccid
        pkgs.p11-kit
      ]);

    # Firefox integration
    programs.firefox.nativeMessagingHosts.packages = [ cfg.package ];

    # Chrome/Chromium integration via environment.etc
    environment.etc = {
      "chromium/native-messaging-hosts/br.com.softplan.webpki.json".source = 
        "${cfg.package}/etc/chromium/native-messaging-hosts/br.com.softplan.webpki.json";
      "chromium/native-messaging-hosts/manifest.json".source = 
        "${cfg.package}/etc/chromium/native-messaging-hosts/manifest.json";
      "opt/chrome/native-messaging-hosts/br.com.softplan.webpki.json".source = 
        "${cfg.package}/etc/opt/chrome/native-messaging-hosts/br.com.softplan.webpki.json";
      "opt/chrome/native-messaging-hosts/manifest.json".source = 
        "${cfg.package}/etc/opt/chrome/native-messaging-hosts/manifest.json";
    };

    # Smart card support
    services.pcscd.enable = mkIf cfg.enableSmartCardSupport true;
    
    # Enable PKCS#11 support
    environment.variables = mkIf cfg.enableSmartCardSupport {
      PCSCLITE_LIBRARY = "${pkgs.pcsclite}/lib/libpcsclite.so.1";
      OPENSC_LIBS = "${pkgs.opensc}/lib";
    };

    # Security wrappers (if needed for specific smart card operations)
    security.wrappers = mkIf cfg.enableSmartCardSupport {
      opensc-tool = {
        source = "${pkgs.opensc}/bin/opensc-tool";
        owner = "root";
        group = "root";
        capabilities = "cap_sys_rawio+ep";
      };
      pkcs11-tool = {
        source = "${pkgs.opensc}/bin/pkcs11-tool";
        owner = "root";
        group = "root";
        capabilities = "cap_sys_rawio+ep";
      };
    };

    # Add users to necessary groups for smart card access
    users.groups.scard = {};
    
    # udev rules for smart card readers
    services.udev.packages = mkIf cfg.enableSmartCardSupport [ 
      pkgs.ccid 
      pkgs.opensc 
    ];
  };

  meta = {
    maintainers = with lib.maintainers; [ ];
  };
} 