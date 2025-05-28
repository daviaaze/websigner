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

    enablePkcs12Support = mkOption {
      type = types.bool;
      default = true;
      description = "Enable PKCS #12 (PFX) certificate file support for digital signatures.";
    };

    customCertificates = mkOption {
      type = types.listOf types.path;
      default = [];
      description = "List of custom CA certificate files to add to the system trust store.";
      example = literalExpression ''[ ./my-ca.crt ./company-root.pem ]'';
    };
  };

  config = mkIf cfg.enable {
    # Install WebSigner package and PKCS #12 tools
    environment.systemPackages = [ cfg.package ] ++ 
      (optionals cfg.enablePkcs12Support [
        pkgs.openssl          # For PKCS #12 operations
        pkgs.p11-kit          # Certificate management
        pkgs.nss              # Mozilla NSS for certificate stores
        pkgs.openjdk          # Java keystore tools (keytool)
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

    # Custom certificate support
    security.pki.certificates = cfg.customCertificates;

    # PKCS #12 and Java keystore support
    environment.variables = mkIf cfg.enablePkcs12Support {
      # Java truststore environment (for custom certificates in Java apps)
      JAVAX_NET_SSL_TRUSTSTORE = let
        caBundle = config.environment.etc."ssl/certs/ca-certificates.crt".source;
        javaCaCerts = pkgs.runCommand "java-cacerts" {
          nativeBuildInputs = [ pkgs.p11-kit ];
        } ''
          trust extract \
            --format=java-cacerts \
            --purpose=server-auth \
            --filter=ca-anchors \
            $out
        '';
      in "${javaCaCerts}";
      
      # OpenSSL configuration
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      SSL_CERT_DIR = "/etc/ssl/certs";
    };

    # Create directories for user certificates
    environment.etc."websigner/certificates/.keep".text = "";
    
    # System-wide certificate store updates
    security.pki.installCACerts = mkDefault true;
  };

  meta = {
    maintainers = with lib.maintainers; [ ];
  };
} 