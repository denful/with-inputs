inputs:
(inputs.nixpkgs.lib.evalModules {
  specialArgs.inputs = inputs;
  modules = [ ./den.nix ];
}).config.flake
