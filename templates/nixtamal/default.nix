{
  with-inputs ? import ./with-inputs.nix,
  follows ? ./follows.nix,
  outputs ? ./outputs.nix,
  from ? "npins",
  ...
}:
with-inputs follows outputs
