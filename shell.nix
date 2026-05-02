{
  pkgs ? import (import ./fixtures/npins).nixpkgs { },
}:
pkgs.mkShell {
  buildInputs = [
    pkgs.just
    pkgs.nix-unit
    pkgs.npins
    pkgs.treefmt
    pkgs.nixfmt
    pkgs.niv
    pkgs.nixtamal
    pkgs.lon
  ];
}
