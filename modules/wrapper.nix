{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options = {
    overrideAttrs = mkOption {
      type = types.functionTo types.attrs;
      default = lib.id;
      description = "Function to override attributes from the final package.";
    };
    wrapped = mkOption {
      description = "Wrapped package.";
      type = types.package;
      readOnly = true;
      apply = package: package.overrideAttrs config.overrideAttrs;
    };
  };
}
