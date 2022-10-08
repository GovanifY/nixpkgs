{ callPackage }:

{
  runTranspiler = callPackage ./transpiler.nix { };
  mkProgram = callPackage ./package.nix { };
  helpers = callPackage ./helpers.nix { };
}
