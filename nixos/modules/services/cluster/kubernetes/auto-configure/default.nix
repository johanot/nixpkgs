{ config, lib, ... }: {

  imports = [
    ./control-plane.nix
    ./pki.nix
  ];

  options.services.kubernetes.autoConfigure = with lib; with lib.types; {
    enable = mkEnableOption "kubernetes auto-configuration";

    authorizationMode = mkOption {
      description = lib.mdDoc ''
        Kubernetes apiserver authorization modes. See:
        <https://kubernetes.io/docs/reference/access-authn-authz/authorization/>
       '';
       default = ["RBAC" "Node"];
       type = listOf str;
    };

    serviceAccountIssuer = mkOption {
      description = lib.mdDoc ''
        Kubernetes apiserver ServiceAccount issuer.
      '';
      default = "https://kubernetes.default.svc";
      type = str;
    };

    serviceClusterIpRange = mkOption {
      description = lib.mdDoc ''
        A CIDR notation IP range from which to assign service cluster IPs.
        This must not overlap with any IP ranges assigned to nodes for pods.
      '';
      default = "10.0.0.0/24";
      type = str;
    };
  };
}
