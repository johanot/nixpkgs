{ config, lib, pkgs, ... }: with lib;
let
  top = config.services.kubernetes;
  cfg = top.proxy;

  # TODO: Remove in NixOS 24.05
  removedOptions = {
    "extraOpts" = "Use freeform settings";
  };

  # TODO: Remove in NixOS 24.05
  optName = n: builtins.filter (f: f != []) (builtins.split "\\." n);

  # map old NixOS-module invented options to their freeform upstream-matching counterparts
  # TODO: Remove in NixOS 24.05
  renamedOptions = {
    "bindAddress" = "bind-address";
    "featureGates" = "feature-gates";
    "hostname" = "hostname-override";
    "kubeconfig" = "kubeconfig";
    "verbosity" = "v";
  };
in
{
  # TODO: Remove in NixOS 24.05
  imports =
    let
      base = ["services" "kubernetes" "proxy"];
    in
      (mapAttrsToList (n: v: mkRemovedOptionModule (base ++ [n]) v) removedOptions) ++
      (mapAttrsToList (n: v: mkRenamedOptionModule (base ++ (optName n)) (base ++ ["settings" v])) renamedOptions);

  ###### interface
  options.services.kubernetes.proxy = with lib.types; {

    enable = mkEnableOption (lib.mdDoc "Kubernetes proxy");

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
    systemd.services.kube-proxy = {
      description = "Kubernetes Proxy Service";
      wantedBy = [ "kubernetes.target" ];
      after = [ "kube-apiserver.service" ];
      path = with pkgs; [ iptables conntrack-tools ];
      serviceConfig = {
        Slice = "kubernetes.slice";
        ExecStart = ''${top.package}/bin/kube-proxy \
          ${concatStringsSep " \\\n" (mapAttrsToList (n: v: ''--${n}="${top.lib.renderArg v}"'') cfg.settings)}
        '';
        WorkingDirectory = top.dataDir;
        Restart = "on-failure";
        RestartSec = 5;
      };
      unitConfig.StartLimitIntervalSec = 0;
    };
  };
}
