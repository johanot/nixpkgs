{ config, lib, ... }: with lib;
let
  top = config.services.kubernetes;
  cfg = top.autoConfigure;

  isNode = elem "node" top.roles;
in
{
  config = mkIf isNode {

  };
}