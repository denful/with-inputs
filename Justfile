help:
  just -l

ci:
  nix-unit ./tests.nix

fmt:
  nixfmt .
