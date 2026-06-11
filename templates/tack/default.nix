{
  with-inputs ? import ./with-inputs.nix,
  follows ? ./follows.nix,
  outputs ? ./outputs.nix,
  ...
}:
with-inputs follows outputs
