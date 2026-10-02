{
  inputsOverrides ? { },
}:
let
  withInputs = import ../../. (import ../npins) [
    (i: {
      nixpkgs2.follows = "nixpkgs";
    })
    inputsOverrides
  ];
in
withInputs (inputs: {
  usedNixpkgs = inputs.nixpkgs2;
})
