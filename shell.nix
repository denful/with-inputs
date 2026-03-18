{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  buildInputs = [
    pkgs.nix-unit
    pkgs.npins
    pkgs.treefmt
    pkgs.nixfmt
  ];
}
