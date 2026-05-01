let
  may-import =
    thing:
    if builtins.isPath thing || builtins.isString thing || thing ? outPath then
      import (builtins.toString thing)
    else
      thing;

  with-inputs =
    sources: follows:
    let
      f = import ./with-inputs.nix (may-import sources) (may-import follows);
    in
    f
    // {
      __functor = _: outputs: f (may-import outputs);
    };

in
{
  __functor = _: with-inputs;
}
