{
  lib,
  symlinkJoin,
  makeWrapper,
  makeBinaryWrapper,
  wrapWith,
}:
(lib.extendMkDerivation {
  constructDrv = symlinkJoin;
  inheritFunctionArgs = false;
  extendDrvArgs =
    let
      errors = {
        key = "`key` must be a valid POSIX name.";
        setDefault = "`setDefault` conflicts with `unset`.";
        unset = "Cannot set `value` in `unset` mode.";
        value = "`value` cannot be empty.";
        wrapperImpl = "`wrapperImpl` must be either `binary` or `shell`.";
      };

      mapRuntimeEnvs =
        envs:
        lib.foldAttrs (item: acc: item ++ acc) [ ] (
          lib.mapAttrsToList (
            name:
            {
              key ? name,
              value ? "",
              setDefault ? true,
              unset ? false,
            }:
            assert lib.isValidPosixName key || throw errors.key;
            assert !setDefault || !unset || throw errors.setDefault;
            assert value == "" || !unset || throw errors.unset;
            assert value != "" || unset || throw errors.value;
            let
              kv = "${key} ${lib.escapeShellArg value}";
            in
            if unset then
              { unset = [ key ]; }
            else if setDefault then
              { set-default = [ kv ]; }
            else
              { set = [ kv ]; }
          ) envs
        );

      mapEnvFixes =
        fixes:
        lib.mapAttrsToList (
          name:
          {
            key ? name,
            sep,
            value,
          }:
          assert lib.isValidPosixName key || throw errors.key;
          "${key} ${sep} ${lib.escapeShellArg value}"
        ) fixes;

      mapFlags = flags: map (flag: lib.escapeShellArg flag) flags;

      toWrapperArgs =
        args:
        lib.cli.toCommandLine
          (optionName: {
            option = "--${optionName}";
            sep = " ";
            explicitBool = false;
          })
          (
            lib.zipAttrsWith (_: values: lib.flatten values) [
              (
                mapRuntimeEnvs args.runtimeEnvs
                // {
                  prefix = mapEnvFixes (
                    args.prefixEnvs
                    // (
                      if args.runtimeInputs == [ ] then
                        { }
                      else
                        {
                          PATH = {
                            sep = ":";
                            value = lib.makeBinPath args.runtimeInputs;
                          };
                        }
                    )
                  );
                  suffix = mapEnvFixes args.suffixEnvs;
                  chdir = lib.mapNullable lib.escapeShellArg args.chdir;
                  run = lib.mapNullable lib.escapeShellArg args.run;
                  add-flag = mapFlags args.prependFlags;
                  append-flag = mapFlags args.appendFlags;
                }
              )
              args.extraArgs
            ]
          );

      toWrapperCommand =
        wrapper:
        let
          makeWrapper =
            if wrapper.wrapperImpl == "binary" then
              "makeBinaryWrapper"
            else if wrapper.wrapperImpl == "shell" then
              "makeShellWrapper"
            else
              throw errors.wrapperImpl;
          wrapProgram =
            if wrapper.wrapperImpl == "binary" then
              "wrapProgramBinary"
            else if wrapper.wrapperImpl == "shell" then
              "wrapProgramShell"
            else
              throw errors.wrapperImpl;
        in
        map (
          exe:
          if wrapper.targets == [ ] then
            lib.concatStringsSep " " (
              [
                wrapProgram
                (wrapper.prefix + exe)
              ]
              ++ toWrapperArgs wrapper
            )
          else
            map (
              target:
              lib.concatStringsSep " " (
                [
                  makeWrapper
                  (wrapper.prefix + exe)
                  (wrapper.prefix + target)
                ]
                ++ toWrapperArgs wrapper
              )
            ) wrapper.targets
        ) wrapper.exes;

      mapWrappers =
        wrappers:
        lib.flatten (
          lib.mapAttrsToList (
            name:
            {
              wrapperImpl ? "binary",
              prefix ? "$out/bin/",
              exes ? [ "${name}" ],
              targets ? [ ],
              runtimeInputs ? [ ],
              runtimeEnvs ? { },
              prefixEnvs ? { },
              suffixEnvs ? { },
              chdir ? null,
              run ? null,
              prependFlags ? [ ],
              appendFlags ? [ ],
              extraArgs ? { },
            }:
            assert
              lib.length exes == 1
              || targets == [ ]
              || throw "Multiple `exes` are not supported when `targets` is set.";
            assert
              wrapperImpl == "shell" || run == null || throw "`run` is only supported for `shell` wrappers.";
            toWrapperCommand {
              inherit
                wrapperImpl
                prefix
                exes
                targets
                runtimeInputs
                runtimeEnvs
                prefixEnvs
                suffixEnvs
                chdir
                run
                prependFlags
                appendFlags
                extraArgs
                ;
            }
          ) wrappers
        );
    in
    finalAttrs:
    {
      package,
      wrappers ? { },
      extraPaths ? [ ],
      extraNativeBuildInputs ? [ ],
      postWrap ? "",
      ...
    }:
    {
      __structuredAttrs = true;
      pname = lib.getName finalAttrs.package;
      version = lib.getVersion finalAttrs.package;
      inherit (finalAttrs.package) meta outputs;
      passthru = finalAttrs.package.passthru or { } // {
        wrapper-unwrapped = finalAttrs.package;
      };

      paths = [ finalAttrs.package ] ++ finalAttrs.extraPaths or [ ];
      nativeBuildInputs = [
        makeWrapper
        makeBinaryWrapper
      ]
      ++ finalAttrs.extraNativeBuildInputs or [ ];
      postBuild = ''
        ${lib.concatStringsSep "\n" (mapWrappers finalAttrs.wrappers or { })}

        ${finalAttrs.postWrap or ""}
      '';
    };
})
// {
  modules.default.imports = [ (lib.modules.importApply ./module.nix { inherit wrapWith; }) ];
}
