{ config, lib, ... }: with lib;
let
  top = config.services.kubernetes;
  cfg = top.autoConfigure;
  pki = services.kubernetes.pki;

  isControlPlane = elem "master" top.roles;

  isRBACEnabled = elem "RBAC" top.apiserver.settings.authorization-mode;

  apiserverServiceIP = (concatStringsSep "." (
    take 3 (splitString "." top.autoConfigure.serviceClusterIpRange
  )) + ".1");
in
{
  config = mkIf (cfg.enable && isControlPlane) {

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

    services.kubernetes.pki.certs = with top.lib; {
      apiServer = mkCert {
        name = "kube-apiserver";
        CN = "kubernetes";
        hosts = [
          "kubernetes.default.svc"
          "kubernetes.default.svc.${top.addons.dns.clusterDomain}"
          top.apiserver.settings.advertise-address
          top.masterAddress
          apiserverServiceIP
          "127.0.0.1"
        ] ++ top.pki.apiServerExtraSANs;
        action = "systemctl restart kube-apiserver.service";
      };
      apiserverProxyClient = mkCert {
        name = "kube-apiserver-proxy-client";
        CN = "front-proxy-client";
        action = "systemctl restart kube-apiserver.service";
      };
      apiserverKubeletClient = mkCert {
        name = "kube-apiserver-kubelet-client";
        CN = "system:kube-apiserver";
        action = "systemctl restart kube-apiserver.service";
      };
      apiserverEtcdClient = mkCert {
        name = "kube-apiserver-etcd-client";
        CN = "etcd-client";
        action = "systemctl restart kube-apiserver.service";
      };
      clusterAdmin = mkCert {
        name = "cluster-admin";
        CN = "cluster-admin";
        fields = {
          O = "system:masters";
        };
        privateKeyOwner = "root";
      };
      controllerManager = mkCert {
        name = "kube-controller-manager";
        CN = "kube-controller-manager";
        action = "systemctl restart kube-controller-manager.service";
      };
      controllerManagerClient = mkCert {
        name = "kube-controller-manager-client";
        CN = "system:kube-controller-manager";
        action = "systemctl restart kube-controller-manager.service";
      };
      etcd = mkCert {
        name = "etcd";
        CN = top.masterAddress;
        hosts = [
                  "etcd.local"
                  "etcd.${top.addons.dns.clusterDomain}"
                  top.masterAddress
                  top.apiserver.settings.advertise-address
                ];
        privateKeyOwner = "etcd";
        action = "systemctl restart etcd.service";
      };
      schedulerClient = top.lib.mkCert {
        name = "kube-scheduler-client";
        CN = "system:kube-scheduler";
        action = "systemctl restart kube-scheduler.service";
      };
    };
  };
}
