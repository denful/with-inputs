{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nixpkgs-hm.follows = "home-manager/nixpkgs";
    den.url = "github:denful/den";
    with-inputs.url = "github:denful/with-inputs";
    with-inputs.flake = false;
  };
  outputs = _: { };
}
