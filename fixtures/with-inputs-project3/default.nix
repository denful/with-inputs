{
  inputsOverrides ? { },
}:
let
  withInputs = import ../../. (import ../npins) [
    (i: {
      common-dep.outPath = ../with-inputs-project;
      nixpkgs3.follows = "common-dep/nixpkgs2";
    })
    inputsOverrides
  ];
in
withInputs (inputs: {
  usedNixpkgs = inputs.nixpkgs3;
})
