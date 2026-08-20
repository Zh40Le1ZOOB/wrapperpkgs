{ wrapWith }:

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  pathsType = types.listOf types.path;

  envsType = types.attrsOf (
    types.submodule (
      { name, config, ... }: {
        options = {
          key = mkOption {
            description = "Name of the variable.";
            type = types.str;
            default = name;
          };
          value = mkOption {
            description = "Value of the variable.";
            type = types.str;
            default = "";
          };
          setDefault = mkOption {
            description = ''
              Only set if not already set.

              Conflicts with `unset`.
            '';
            type = types.bool;
            default = true;
          };
          unset = mkOption {
            description = ''
              Unset instead of setting.

              Conflicts with `setDefault`.
            '';
            type = types.bool;
            default = false;
          };
        };
      }
    )
  );

  envFixesType = types.attrsOf (
    types.submodule (
      { name, ... }: {
        options = {
          key = mkOption {
            description = "Name of the variable.";
            type = types.str;
            default = name;
          };
          sep = mkOption {
            description = "Separator of the prefix/suffix.";
            type = types.str;
          };
          value = mkOption {
            description = "Value of the prefix/suffix.";
            type = types.str;
          };
        };
      }
    )
  );

  wrappersType = types.attrsOf (
    types.submodule (
      {
        name,
        config,
        ...
      }:
      {
        options = {
          wrapperImpl = mkOption {
            description = "Whether to use a binary or a shell wrapper.";
            type = types.enum [
              "binary"
              "shell"
            ];
            default = "binary";
          };
          prefix = mkOption {
            description = "Prefix of the executable and its wrapper.";
            type = types.str;
            default = "$out/bin/";
          };
          exes = mkOption {
            description = "
              Executables to wrap.

              Must not be empty.
              Executables will be wrapped in place by default.";
            type = types.listOf types.str;
            default = [ "${name}" ];
          };
          targets = mkOption {
            description = ''
              Wrapper names to create.

              Only supported with a single `exes` entry.
              Default in-place wrapping is skipped when set.
            '';
            type = types.listOf types.str;
            default = [ ];
          };
          runtimeInputs = mkOption {
            description = "Packages added to the wrapper's `PATH`.";
            type = pathsType;
            default = [ ];
          };
          runtimeEnvs = mkOption {
            description = "Environment variables managed by the wrapper.";
            type = envsType;
            default = { };
          };
          prefixEnvs = mkOption {
            description = "Environment variables to prefix.";
            type = envFixesType;
            default = { };
          };
          suffixEnvs = mkOption {
            description = "Environment variables to suffix.";
            type = envFixesType;
            default = { };
          };
          chdir = mkOption {
            description = "Working directory of the wrapper.";
            type = types.nullOr types.path;
            default = null;
          };
          run = mkOption {
            description = ''
              Command to run before the executable.

              Only supported for `shell` wrappers.
            '';
            type = types.nullOr types.lines;
            default = null;
          };
          prependFlags = mkOption {
            description = "Flags passed before any arguments.";
            type = types.listOf types.str;
            default = [ ];
          };
          appendFlags = mkOption {
            description = "Flags passed after any arguments.";
            type = types.listOf types.str;
            default = [ ];
          };
          extraArgs = mkOption {
            description = "Extra arguments passed to the wrapper command.";
            type = types.attrsOf types.anything;
            default = { };
          };
        };
      }
    )
  );
in
{
  _class = "wrapper";

  options = {
    package = mkOption {
      description = "The package to wrap.";
      type = types.package;
    };
    wrappers = mkOption {
      description = "Wrappers to create.";
      type = wrappersType;
      default = { };
    };
    extraPaths = mkOption {
      description = "Extra directories linked into the output.";
      type = pathsType;
      default = [ ];
    };
    extraNativeBuildInputs = mkOption {
      description = "Additional nativeBuildInputs.";
      type = pathsType;
      default = [ ];
    };
    postWrap = mkOption {
      description = "Shell commands run after the wrapper commands.";
      type = types.lines;
      default = "";
    };
  };

  config.wrapped = wrapWith {
    inherit (config)
      package
      wrappers
      extraPaths
      extraNativeBuildInputs
      postWrap
      ;
  };
}
