import ./make-test-python.nix ({ pkgs, lib, ...}: 
let
  domain = "my.zyx";
  replicas = 64;

  redisPod = pkgs.writeText "redis-pod.json" (builtins.toJSON {
    kind = "Deployment";
    apiVersion = "apps/v1";
    metadata.name = "redis";
    metadata.labels.name = "redis";
    spec = {
      inherit replicas;
      selector.matchLabels.deploy = "redis";
      template = {
        metadata.labels.deploy = "redis";
        spec.containers = [{
          name = "redis";
          image = "redis";
          args = ["--bind" "0.0.0.0"];
          imagePullPolicy = "Never";
          ports = [{
            name = "redis-server";
            containerPort = 6379;
          }];
        }];
      };
    };
  });

  redisService = pkgs.writeText "redis-service.json" (builtins.toJSON {
    kind = "Service";
    apiVersion = "v1";
    metadata.name = "redis";
    spec = {
      ports = [{port = 6379; targetPort = 6379;}];
      selector = {deploy = "redis";};
    };
  });

  redisImage = pkgs.dockerTools.buildImage {
    name = "redis";
    tag = "latest";
    contents = [ pkgs.redis pkgs.bind.host ];
    config.Entrypoint = ["/bin/redis-server"];
  };
in
{
  meta.maintainers = with lib.maintainers; [ hexa ];

  nodes = {
    router = { config, pkgs, ... }: {
      virtualisation.vlans = [ 1 2 ];

      networking = {
        useNetworkd = true;
        useDHCP = false;
        firewall.allowedUDPPorts = [ 67 ];
      };

      systemd.network = {
        networks = {
          "01-eth2" = {
            name = "eth2";
            networkConfig = {
              Address = "10.100.0.1/30";
            };
          };
        };
      };

      services.kea.dhcp4 = {
        enable = true;
        settings = {
          valid-lifetime = 10;
          renew-timer = 5;
          rebind-timer = 10;

          lease-database = {
            type = "memfile";
            persist = true;
            name = "/var/lib/kea/dhcp4.leases";
          };

          interfaces-config = {
            dhcp-socket-type = "raw";
            interfaces = [
              "eth2"
            ];
          };

          subnet4 = [ {
            subnet = "10.100.0.0/30";
            pools = [ {
              pool = "10.100.0.2 - 10.100.0.2";
            } ];
          } ];
        };
      };
    };

    client = { config, pkgs, ... }: {
      virtualisation.vlans = [ 1 2 ];

      imports = [
        ./kea-kubernetes.nix
      ];

      lib.options.masterName = "client";
      lib.options.domain = domain;
      lib.options.masterIP = "10.100.0.2";
      lib.options.machines = {
        client = { ip = "10.100.0.2"; };
      };

      #systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
      networking = {
        useNetworkd = true;
        useDHCP = false;
        firewall.enable = false;
        interfaces.eth2.useDHCP = true;
      };
    };
  };
  testScript = { ... }: ''
    start_all()
    router.wait_for_unit("kea-dhcp4-server.service")
    client.wait_for_unit("systemd-networkd-wait-online.service")
    client.wait_until_succeeds("ping -c 5 10.100.0.1")
    router.wait_until_succeeds("ping -c 5 10.100.0.2")

    client.wait_until_succeeds("kubectl get node client.${domain} | grep -w Ready")

    client.wait_until_succeeds(
        "${pkgs.gzip}/bin/zcat ${redisImage} | ${pkgs.containerd}/bin/ctr -n k8s.io image import -"
    )
    client.wait_until_succeeds(
        "kubectl create -f ${redisPod}"
    )
    client.wait_until_succeeds(
        "kubectl create -f ${redisService}"
    )

    # check if pods are running
    client.wait_until_succeeds("test $(kubectl get pod | grep -c Running) -eq ${toString replicas}")

    client.succeed("kubectl rollout restart deploy redis")

    client.wait_until_succeeds("networkctl | grep eth2 |grep failed")
  '';
})
