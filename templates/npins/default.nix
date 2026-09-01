{
  inputsOverrides ? { },
}:
import ./with-inputs.nix [ ./follows.nix inputsOverrides ] ./outputs.nix
