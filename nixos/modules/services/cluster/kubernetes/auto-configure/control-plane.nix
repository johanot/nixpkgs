{ config, lib, ... }: with lib;
let
  top = config.services.kubernetes;
  cfg = top.autoConfigure;
  pki = services.kubernetes.pki;

  isControlPlaneNode = elem "master" top.roles;

  isRBACEnabled = elem "RBAC" top.apiserver.settings.authorization-mode;

in
{
  config = mkIf (cfg.enable && isControlPlaneNode) {

    meta.buildDocsInSandbox = false;

    services.kubernetes.apiserver.settings = {
      api-audiences = "api,${cfg.serviceAccountIssuer}";
      authorization-mode = cfg.authorizationMode;
      service-cluster-ip-range = cfg.serviceClusterIpRange;
      service-account-issuer = cfg.serviceAccountIssuer;
    };

    services.kubernetes.controllerManager.settings = {
      allocate-node-cidrs = true;
      cluster-cidr = top.clusterCidr; #TODOk8s: these top-level options might disappear?
      use-service-account-credentials = mkDefault isRBACEnabled;
    };

    services.etcd = {
      clientCertAuth = mkDefault true;
      peerClientCertAuth = mkDefault true;
      listenClientUrls = mkDefault ["https://0.0.0.0:2379"];
      listenPeerUrls = mkDefault ["https://0.0.0.0:2380"];
      advertiseClientUrls = mkDefault ["https://${top.masterAddress}:2379"];
      initialCluster = mkDefault ["${top.masterAddress}=https://${top.masterAddress}:2380"];
      name = mkDefault top.masterAddress;
      initialAdvertisePeerUrls = mkDefault ["https://${top.masterAddress}:2380"];
    };

    services.kubernetes.addonManager.bootstrapAddons = mkIf isRBACEnabled {
      apiserver-kubelet-api-admin-crb = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRoleBinding";
        metadata = {
          name = "system:kube-apiserver:kubelet-api-admin";
        };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "system:kubelet-api-admin";
        };
        subjects = [{
          kind = "User";
          name = "system:kube-apiserver";
        }];
      };
    };
  };
}
