{
  # Note: no inputs.nixpkgs declared — outputs takes `nixpkgs` indirectly.
  outputs =
    { nixpkgs, ... }:
    {
      usedNixpkgs = nixpkgs;
    };
}
