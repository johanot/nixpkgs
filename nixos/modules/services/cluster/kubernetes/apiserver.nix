{ config, lib, pkgs, ... }: with lib;
let
  top = config.services.kubernetes;
  cfg = top.apiserver;

  # TODO: Remove in NixOS 24.05
  removedOptions = {
    "authorizationPolicy" = "Generate a policy file and set 'settings.authorization-policy-file' to its path";
    "basicAuthFile" = "Support for basic auth was removed in Kubernetes v1.19";
    "extraOpts" = "Use freeform settings";
  };

  # TODO: Remove in NixOS 24.05
  optName = n: builtins.filter (f: f != []) (builtins.split "\\." n);

  # map old NixOS-module invented options to their freeform upstream-matching counterparts
  # TODO: Remove in NixOS 24.05
  renamedOptions = {
    "apiAudiences" = "api-audiences";
    "allowPrivileged" = "allow-privileged";
    "authorizationMode" = "authorization-mode";
    "advertiseAddress" = "advertise-address";
    "bindAddress" = "bind-address";
    "clientCaFile" = "client-ca-file";
    "disableAdmissionPlugins" = "disable-admission-plugins";
    "enableAdmissionPlugins" = "enable-admission-plugins";
    "etcd.caFile" = "etcd-cafile";
    "etcd.certFile" = "etcd-certfile";
    "etcd.keyFile" = "etcd-keyfile";
    "etcd.servers" = "etcd-servers";
    "featureGates" = "feature-gates";
    "kubeletClientCaFile" = "kubelet-certificate-authority";
    "kubeletClientCertFile" = "kubelet-client-certificate";
    "kubeletClientKeyFile" = "kubelet-client-key";
    "preferredAddressTypes" = "kubelet-preferred-address-types";
    "proxyClientCertFile" = "proxy-client-cert-file";
    "proxyClientKeyFile" = "proxy-client-key-file";
    "runtimeConfig" = "runtime-config";
    "storageBackend" = "storage-backend";
    "securePort" = "secure-port";
    "serviceAccountIssuer" = "service-account-issuer";
    "serviceAccountSigningKeyFile" = "service-account-signing-key-file";
    "serviceAccountKeyFile" = "service-account-key-file";
    "serviceClusterIpRange" = "service-cluster-ip-range";
    "tlsCertFile" = "tls-cert-file";
    "tlsKeyFile" = "tls-private-key-file";
    "tokenAuthFile" = "token-auth-file";
    "verbosity" = "v";
    "webhookConfig" = "authentication-token-webhook-config-file";
  };

  render = v:
    if isList v
    then concatStringsSep "," v
    else toString v;
in
{
  # TODO: Remove in NixOS 24.05
  imports =
    let
      base = ["services" "kubernetes" "apiserver"];
    in
      [
        (mkRenamedOptionModule (base ++ ["extraSANs"]) ["services" "kubernetes" "pki" "apiServerExtraSANs"])
      ] ++
      (mapAttrsToList (n: v: mkRemovedOptionModule (base ++ [n]) v) removedOptions) ++
      (mapAttrsToList (n: v: mkRenamedOptionModule (base ++ (optName n)) (base ++ ["settings" v])) renamedOptions);

  ###### interface
  options.services.kubernetes.apiserver = with types; {
    enable = mkEnableOption (mdDoc "Kubernetes apiserver");

    settings = mkOption {
      type = types.submodule {
        freeformType = attrsOf (oneOf [
          bool
          float
          int
          (listOf str)
          package
          path
          str
        ]);
      };
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    systemd.services.kube-apiserver = {
      description = "Kubernetes APIServer Service";
      wantedBy = [ "kubernetes.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Slice = "kubernetes.slice";
        ExecStart = ''${top.package}/bin/kube-apiserver \
          ${concatStringsSep " \\\n" (mapAttrsToList (n: v: ''--${n}="${render v}"'') cfg.settings)}
        '';
        WorkingDirectory = top.dataDir;
        User = "kubernetes";
        Group = "kubernetes";
        AmbientCapabilities = "cap_net_bind_service";
        Restart = "on-failure";
        RestartSec = 5;
      };
      unitConfig.StartLimitIntervalSec = 0;
    };
  };
}
