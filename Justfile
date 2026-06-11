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
  just loader tack

loader name *args:
  cd templates/{{name}} && \
   nix eval --raw --file ./. \
   --arg with-inputs '(import ../..).from.{{name}} ./.' \
   nixosConfigurations.igloo.config.home-manager.users.tux.home.username \
   {{args}}

fmt:
  treefmt

fmt-check:
  treefmt --ci
