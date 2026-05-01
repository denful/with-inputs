help:
  just -l

ci:
  just tests
  just loaders
  just fmt-check

tests:
  nix-unit ./tests.nix

loaders:
  just loader npins
  just loader niv
  just loader lon
  just loader unflake
  just loader flake
  just loader nixtamal

loader name:
  cd templates/{{name}} && \
   nix-instantiate --eval --strict --json ./. \
   --arg with-inputs '(import ../..).from.{{name}} ./.' \
   -A nixosConfigurations.igloo.config.home-manager.users.tux.home.username

fmt:
  treefmt

fmt-check:
  treefmt --ci
