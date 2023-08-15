{ config, lib, ... }:
let
  top = config.services.kubernetes;
  cfg = top.autoConfigure;
  hostname = config.networking.fqdnOrHostName;
in
{
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

  config = lib.mkIf cfg.enable {
    services.kubernetes.proxy.settings = {
      cluster-cidr = top.clusterCidr; #TODOk8s: these top-level options might disappear?
    };
    services.kubernetes.kubelet.settings = {
      cgroup-driver = "systemd";
      cluster-dns = top.addons.dns.clusterIp;
      hostname-override = hostname;
    };

    services.kubernetes.pki.certs = with top.lib; {
      kubeProxyClient = top.lib.mkCert {
        name = "kube-proxy-client";
        CN = "system:kube-proxy";
        action = "systemctl restart kube-proxy.service";
      };
      kubelet = mkCert {
        name = "kubelet";
        CN = hostname;
        action = "systemctl restart kubelet.service";

      };
      kubeletClient = mkCert {
        name = "kubelet-client";
        CN = "system:node:${hostname}";
        fields = {
          O = "system:nodes";
        };
        action = "systemctl restart kubelet.service";
      };
    };
  };
}
