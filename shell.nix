{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  buildInputs = [
    pkgs.just
    pkgs.nix-unit
    pkgs.npins
    pkgs.treefmt
    pkgs.nixfmt
  ];
}
