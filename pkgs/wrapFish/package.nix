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
    assert lib.getVersion package == "4.9.3";
    let
      error = "`key` must be a valid POSIX name.";

      mapAbbrs =
        abbrs:
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            key: value:
            assert lib.isValidPosixName key || throw error;
            "abbr -a ${key} -- ${lib.escapeShellArg value}"
          ) abbrs
        );

      mapAliases =
        aliases:
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            key: value:
            assert lib.isValidPosixName key || throw error;
            "alias ${key} ${lib.escapeShellArg value}"
          ) aliases
        );

      fishConfig = writeText "config.fish" ''
        ${finalAttrs.config or ""}

        if status is-interactive
          ${mapAbbrs finalAttrs.abbrs or { }}
          ${mapAliases finalAttrs.aliases or { }}
        end
      '';

      configDir =
        runCommand "fish-config-dir"
          {
            env =
              lib.genAttrs
                [
                  "conf"
                  "completions"
                  "functions"
                ]
                (
                  type:
                  lib.escapeShellArgs (
                    map (plugin: (plugin: type: "${plugin}/share/fish/vendor_${type}.d") plugin type)
                      finalAttrs.plugins or [ ]
                    ++ (finalAttrs."extra${
                      {
                        conf = "Conf";
                        completions = "Completions";
                        functions = "Functions";
                      }
                      .${type}
                    }" or [ ]
                    )
                  )
                );
          }
          ''
            mkdir -p $out/conf.d/ $out/completions/ $out/functions/ $out/themes/

            cp ${fishConfig} $out/config.fish

            for theme in ${lib.escapeShellArgs finalAttrs.themes or [ ]}; do
              cp "$theme" $out/themes/
            done

            for pathType in conf completions functions; do
              for path in ''${!pathType}; do
                if test -d $path; then
                  if test $pathType == conf; then
                    cp -r $path/* $out/conf.d/
                  else
                    cp -r $path/* $out/$pathType/
                  fi
                fi
              done
            done
          '';
    in
    {
      package = package.overrideAttrs (oldAttrs: {
        patches = oldAttrs.patches ++ [
          ./patches/preferred_dir_env.patch
          ./patches/vars_path_data_dir.patch
        ];
      });
      wrappers.fish.runtimeEnvs.FISH_CONFIG_DIR.value = configDir;
    };
})
// {
  modules.default.imports = [ (lib.modules.importApply ./module.nix { inherit wrapFish; }) ];
}
