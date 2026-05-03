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

  from.niv = root: with-inputs (root + "/nix/sources.nix");

  from.npins = root: with-inputs (root + "/npins");

  from.lon =
    root:
    let
      lon = import (root + "/lon.nix");
      sources = builtins.mapAttrs (_: outPath: { inherit outPath; }) lon;
    in
    with-inputs sources;

  from.unflake = root: with-inputs (root + "/unflake.nix");

  from.nixtamal = root: with-inputs (import (root + "/nix/tamal") { });

  from.flake =
    root:
    let
      lock = builtins.fromJSON (builtins.readFile (root + "/flake.lock"));
      flake = import (root + "/flake.nix");
      sources = builtins.mapAttrs fetch lock.nodes;
      fetch =
        name: node:
        (flake.inputs.${name} or { })
        // {
          tarball.outPath = builtins.fetchTarball {
            url = node.locked.url;
            sha256 = node.locked.narHash;
          };
          github.outPath = builtins.fetchTarball {
            url = "https://github.com/${node.locked.owner}/${node.locked.repo}/archive/${node.locked.rev}.zip";
            sha256 = node.locked.narHash;
          };
        }
        .${node.locked.type};
    in
    with-inputs sources;

in
{
  inherit from;
  __functor = _: with-inputs;
}
