{ config, lib, pkgs, ... }: with lib; 

let
  kubectl = with pkgs; runCommand "wrap-kubectl" { buildInputs = [ makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${pkgs.kubernetes}/bin/kubectl $out/bin/kubectl --set KUBECONFIG "/etc/kubernetes/cluster-admin.kubeconfig"
  '';

  extraConfiguration = { config, pkgs, lib, ... }: {
    boot.kernelModules = [ "ip_vs" ];
    services.kubernetes.proxy.extraOpts = "--proxy-mode=ipvs";
    systemd.services.kube-proxy.path = with pkgs; [ kmod ipset ];
    environment.systemPackages = with pkgs; [ bind.host ipvsadm ipset iptables nftables ];

    systemd.services.nftapply = {
      enable = false;
      description = "nft apply";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "kubernetes.target"];
      preStart = ''
        ${pkgs.nftables}/bin/nft create table kube-router
      '';
      script = ''
        while true; do
          ${pkgs.nftables}/bin/nft -f ${./kubernetes/kube-router.nft}
        done
      '';
    };

    systemd.services.ipaddrassign1 = {
      enable = true;
      description = "ip addr assign";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "kubernetes.target"];
      script = ''
        while true; do
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.99/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.100/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.101/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.102/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.103/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.104/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.105/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.105/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.104/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.103/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.102/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.101/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.100/32 dev eth0
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.99/32 dev eth0
          sleep 0.1
        done
      '';
    };

    systemd.services.ipaddrassign2 = {
      enable = true;
      description = "ip addr assign";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "kubernetes.target"];
      script = ''
        while true; do
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.99/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.100/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.101/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.102/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.103/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.104/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a add 192.168.99.105/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.105/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.104/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.103/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.102/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.101/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.100/32 dev eth2
          time ${pkgs.iproute2}/bin/ip a del 192.168.99.99/32 dev eth2
          sleep 0.1
        done
      '';
    };

    #systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";

    networking.useNetworkd = true;
    networking.useDHCP = false;
    networking.interfaces.eth0.useDHCP = true;
    systemd.services.cfssl.after = ["network-online.target"];
    systemd.services.certmgr.after = ["cfssl.service"];
    #systemd.services.systemd-networkd.serviceConfig = {
    #  WatchdogSec = 20;
      #Restart = lib.mkForce "never";
    #};
  };

in
with config.lib.options; {
  imports = [ extraConfiguration ];

  boot.postBootCommands = "rm -fr /var/lib/kubernetes/secrets /tmp/shared/*";
  virtualisation.memorySize = mkDefault 8092;
  virtualisation.diskSize = mkDefault 8092;
  networking = 
  let
    extraHosts = ''
        ${masterIP}  etcd.${domain}
        ${masterIP}  api.${domain}
        ${concatMapStringsSep "\n" (machineName: "${machines.${machineName}.ip}  ${machineName}.${domain}") (attrNames machines)}
    '';
  in
  {
    domain = config.lib.options.domain;
    inherit extraHosts;
    primaryIPAddress = mkForce "192.168.1.1";

    firewall = {
      allowedTCPPorts = [
        10250 # kubelet
      ];
      trustedInterfaces = ["mynet"];

      extraCommands = concatMapStrings  (node: ''
        iptables -A INPUT -s ${node.config.networking.primaryIPAddress} -j ACCEPT
      '') (attrValues nodes);
    };
  };
  programs.bash.enableCompletion = true;
  environment.systemPackages = [ kubectl ];
  services.flannel.iface = "eth1";
  services.kubernetes = {
    addons.dashboard.enable = true;
    proxy.hostname = "${masterName}.${domain}";

    easyCerts = true;
    roles = ["master" "node"];
    apiserver = {
      securePort = 443;
      advertiseAddress = "192.168.1.1";
    };
    masterAddress = "${masterName}.${config.networking.domain}";
    # workaround for:
    #   https://github.com/kubernetes/kubernetes/issues/102676
    #   (workaround from) https://github.com/kubernetes/kubernetes/issues/95488
    kubelet.extraOpts = ''\
      --cgroups-per-qos=false \
      --enforce-node-allocatable="" \
    '';
  };
}