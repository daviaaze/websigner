# NixOS module for WebSigner
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.websigner;
  websignerPackage = pkgs.callPackage ./websigner.nix { };
in

{
  options.programs.websigner = {
    enable = mkEnableOption "WebSigner digital signature application";

    package = mkOption {
      type = types.package;
      default = websignerPackage;
      description = "The WebSigner package to use.";
    };

    enableFirefoxIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Firefox native messaging host integration.";
    };

    enableChromiumIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Chromium/Chrome native messaging host integration.";
    };
  };

  config = mkIf cfg.enable {
    # Install the WebSigner package
    environment.systemPackages = [ cfg.package ];

    # Firefox integration
    programs.firefox = mkIf cfg.enableFirefoxIntegration {
      nativeMessagingHosts.packages = [ cfg.package ];
    };

    # Chrome/Chromium integration
    environment.etc = mkMerge [
      (mkIf cfg.enableChromiumIntegration {
        "chromium/native-messaging-hosts/br.com.softplan.webpki.json" = {
          source = "${cfg.package}/etc/chromium/native-messaging-hosts/br.com.softplan.webpki.json";
        };
        "opt/chrome/native-messaging-hosts/br.com.softplan.webpki.json" = {
          source = "${cfg.package}/etc/opt/chrome/native-messaging-hosts/br.com.softplan.webpki.json";
        };
      })
    ];

    # Ensure the WebSigner service can access necessary resources
    security.wrappers = {
      websigner = {
        source = "${cfg.package}/bin/websigner";
        capabilities = "cap_sys_admin+ep";
        owner = "root";
        group = "root";
        permissions = "u+rx,g+x,o+x";
      };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ ];
    doc = ./websigner-module.md;
  };
} 