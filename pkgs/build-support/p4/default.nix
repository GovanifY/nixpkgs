{ callPackage }:

{
  runTranspiler = callPackage ./transpiler.nix { };
  helpers = callPackage ./helpers.nix { };
}
