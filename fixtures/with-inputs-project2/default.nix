{
  inputsOverrides ? { },
}:
let
  withInputs = import ../../. (import ../npins) [
    (i: {
      common-dep.outPath = ../with-inputs-project;
      nixpkgs4.follows = "common-dep/nixpkgs2";
    })
    inputsOverrides
  ];
in
withInputs (inputs: {
  usedNixpkgs = inputs.nixpkgs4;
})
