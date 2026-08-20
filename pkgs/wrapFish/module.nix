{ wrapFish }:

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  pathsType = types.listOf types.path;
in
{
  _class = "wrapper";

  options = {
    package = mkOption {
      description = "The fish package to wrap.";
      type = types.package;
      default = pkgs.fish;
    };
    config = mkOption {
      description = "Fish configuration script.";
      type = types.lines;
      default = "";
    };
    abbrs = mkOption {
      description = "Fish abbreviations.";
      type = types.attrsOf types.str;
      default = { };
    };
    aliases = mkOption {
      description = "Fish aliases.";
      type = types.attrsOf types.str;
      default = { };
    };
    themes = mkOption {
      description = "Themes to install.";
      type = pathsType;
      default = [ ];
    };
    plugins = mkOption {
      description = "Plugins to install.";
      type = types.listOf types.package;
      default = [ ];
    };
    extraConf = mkOption {
      description = "Extra directories whose contents are copied into `conf.d`.";
      type = pathsType;
      default = [ ];
    };
    extraCompletions = mkOption {
      description = "Extra directories whose contents are copied into `completions`.";
      type = pathsType;
      default = [ ];
    };
    extraFunctions = mkOption {
      description = "Extra directories whose contents are copied into `functions`.";
      type = pathsType;
      default = [ ];
    };
  };

  config.wrapped = wrapFish {
    inherit (config)
      package
      config
      abbrs
      aliases
      themes
      plugins
      extraConf
      extraCompletions
      extraFunctions
      ;
  };
}
