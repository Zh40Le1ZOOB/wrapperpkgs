final: prev:
(prev.lib.packagesFromDirectoryRecursive {
  inherit (final) callPackage;
  directory = ../pkgs;
})
// {
  evalWrappers =
    {
      pkgs ? final,
      lib ? pkgs.lib,
      modules ? [ ],
      specialArgs ? { },
    }:
    lib.evalModules {
      modules = [ ../modules ] ++ modules;
      specialArgs = {
        inherit pkgs;
      }
      // specialArgs;
    };
}
