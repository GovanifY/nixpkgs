{ callPackage }:

{
  runTranspiler = callPackage ./transpiler.nix { };
}
