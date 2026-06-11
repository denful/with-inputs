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

  from.tack =
    root:
    let
      dir = root + "/.tack";
      toml = builtins.fromTOML (builtins.readFile (dir + "/pins.toml"));
      pins = toml.inputs or { };
      lock = builtins.fromJSON (builtins.readFile (dir + "/pins.lock.json"));

      fetchFixed =
        name: node:
        let
          raw = derivation {
            inherit name;
            inherit (node) url;
            builder = "builtin:fetchurl";
            system = "builtin";
            outputHash = node.sha256;
            outputHashAlgo = "sha256";
            outputHashMode = "flat";
          };
          unpacked = derivation {
            inherit name;
            builder = "builtin:unpack-channel";
            system = "builtin";
            src = raw;
            channelName = name;
          };
          unpack = node.unpack or (pins.${name}.unpack or "file");
        in
        if unpack == "tarball" then unpacked.outPath + "/" + name else raw.outPath;

      fetchNode =
        name: node:
        {
          github = builtins.fetchTarball {
            url = "https://github.com/${node.owner}/${node.repo}/archive/${node.rev}.zip";
            sha256 = node.narHash;
          };
          tarball = builtins.fetchTarball {
            url = node.url;
            sha256 = node.narHash;
          };
          git = builtins.fetchGit (
            {
              inherit (node) url rev narHash;
            }
            // (if node ? ref then { inherit (node) ref; } else { })
            // (if node ? submodules then { inherit (node) submodules; } else { })
            // (
              if node ? lastModified then
                {
                  inherit (node) lastModified;
                  shallow = true;
                }
              else
                { }
            )
          );
          fixed = fetchFixed name node;
        }
        .${node.type};

      mkSourceEntry =
        name: node:
        let
          pin = pins.${name} or { };
          pinType = pin.type or (if pin.flake or true then "flake" else "fetch");
          fetched = fetchNode name node;
          outPath = if pin ? dir then fetched + "/" + pin.dir else fetched;
        in
        { inherit outPath; } // (if pinType == "flake" then { } else { flake = false; });

      pinned = builtins.mapAttrs mkSourceEntry lock;

      # [all_follow] rows alias pin names; with-inputs resolves sub-inputs by
      # name, so each alias becomes a source entry sharing the target's source.
      allFollow = toml.all_follow or { };
      aliases = builtins.listToAttrs (
        builtins.concatMap (
          key:
          let
            v = allFollow.${key};
          in
          if builtins.isList v then
            map (alias: {
              name = alias;
              value = pinned.${key};
            }) v
          else
            [
              {
                name = key;
                value = pinned.${v};
              }
            ]
        ) (builtins.attrNames allFollow)
      );
    in
    with-inputs (pinned // aliases);

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
          path.outPath = node.locked.path;
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
