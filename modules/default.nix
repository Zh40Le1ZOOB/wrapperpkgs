{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options = {
    wrappers = mkOption {
      description = "Wrappers to create.";
      type = types.attrsOf (
        types.submoduleWith {
          class = "wrapper";
          specialArgs = { inherit pkgs; };
          modules = [ ./wrapper.nix ];
        }
      );
      default = { };
    };
    build.packages = mkOption {
      description = "Wrapped package set.";
      type = types.attrsOf types.package;
      readOnly = true;
    };
  };
  config.build.packages = lib.mapAttrs (_: wrapper: wrapper.wrapped) config.wrappers;
}
