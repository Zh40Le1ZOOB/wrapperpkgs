{
  lib,
  wrapWith,
  writeText,
  runCommand,
  fish,
  wrapFish,
}:
(lib.extendMkDerivation {
  constructDrv = wrapWith;
  extendDrvArgs =
    finalAttrs:
    {
      package ? fish,
      config ? "",
      abbrs ? { },
      aliases ? { },
      themes ? [ ],
      plugins ? [ ],
      extraConf ? [ ],
      extraCompletions ? [ ],
      extraFunctions ? [ ],
      ...
    }:
    assert
      lib.getVersion package == "4.9.3"
      || throw "`package` must be fish version 4.9.3, got ${lib.getVersion package}.";
    let
      errors = {
        key = key: "`${key}` is not a valid POSIX name.";
        target = target: "`target` must not be a nested path, got ${target}.";
      };

      mapAbbrs =
        abbrs:
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            key: value:
            assert lib.isValidPosixName key || throw (errors.key key);
            "abbr -a ${key} -- ${lib.escapeShellArg value}"
          ) abbrs
        );

      mapAliases =
        aliases:
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            key: value:
            assert lib.isValidPosixName key || throw (errors.key key);
            "alias ${key} ${lib.escapeShellArg value}"
          ) aliases
        );

      mapThemes =
        themes:
        lib.concatStringsSep "\n" (
          map (
            theme:
            assert !lib.hasInfix "/" theme.target or "" || throw (errors.target theme.target);
            "cp ${lib.escapeShellArg theme.source} $out/themes/${
              lib.escapeShellArg theme.target or (lib.baseNameOf theme.source)
            }"
          ) themes
        );

      mapPlugins =
        plugins:
        lib.concatStringsSep "\n" (
          lib.flatten (
            map (
              plugin:
              map
                (type: ''
                  path=${plugin}/share/fish/vendor_${type}.d
                  if test -d $path; then
                    cp -r $path/. $out/${if type == "conf" then "conf.d" else type}/
                  fi
                '')
                [
                  "conf"
                  "completions"
                  "functions"
                ]
            ) plugins
          )
        );

      mapVendors =
        vendors: target:
        lib.concatStringsSep "\n" (map (vendor: "cp -r ${vendor}/. $out/${target}/") vendors);

      fishConfig = writeText "config.fish" ''
        ${finalAttrs.config or ""}

        if status is-interactive
          ${mapAbbrs finalAttrs.abbrs or { }}
          ${mapAliases finalAttrs.aliases or { }}
        end
      '';

      configDir = runCommand "fish-config-dir" { } ''
        mkdir -p $out/conf.d/ $out/completions/ $out/functions/ $out/themes/

        cp ${fishConfig} $out/config.fish

        ${mapThemes finalAttrs.themes or [ ]}
        ${mapPlugins finalAttrs.plugins or [ ]}
        ${mapVendors finalAttrs.extraConf or [ ] "conf.d"}
        ${mapVendors finalAttrs.extraCompletions or [ ] "completions"}
        ${mapVendors finalAttrs.extraFunctions or [ ] "functions"}
      '';
    in
    {
      package = package.overrideAttrs (oldAttrs: {
        patches = oldAttrs.patches ++ [
          ./patches/preferred_dir_env.patch
          ./patches/vars_path_data_dir.patch
        ];
      });
      wrappers.fish.runtimeEnvs.FISH_CONFIG_DIR = {
        value = configDir;
        setDefault = false;
      };
    };
})
// {
  modules.default.imports = [ (lib.modules.importApply ./module.nix { inherit wrapFish; }) ];
}
