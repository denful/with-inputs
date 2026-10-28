# Flake-inputs adapter.
#
# Mirrors flake inputs resolution without fetching or locking.
# Expects pre-fetched sources (npins, unflake, local paths, anything with .outPath).
#
# sources:  attrset of name -> sourceInfo (e.g. from npins)
# inputsOverrides:  [list of] attrset (or inputs -> attrset) mirroring the `inputs` block of a flake.nix:
#   someLib.outPath = ./someLib;              local checkout (loaded as flake if possible)
#   b.follows = "a";                          alias to allInputs.a
#   b.follows = "a/x/y";                      nested follows
#   b.follows = "";                           intentionally empty
#   a.inputs.b.follows = "nixpkgs";           per-sub-input follows override
#   a = { outPath = ./a; inputs.b.follows = "x"; };  outPath + sub-input overrides
#   a = anyValue;                             direct value (function, attrset, …)
sources: inputsOverrides:
let
  inputs =
    let
      f =
        io:
        builtins.removeAttrs (if builtins.isAttrs io then io else (__functor allInputs io).outputs) [
          "self"
        ];
    in
    if builtins.isList inputsOverrides then
      builtins.foldl' (x: y: x // (f y)) { } inputsOverrides
    else
      f inputsOverrides;

  splitPath = s: builtins.filter builtins.isString (builtins.split "/" s);

  isFollows = v: builtins.isAttrs v && v ? follows;

  specKeys = [
    "follows"
    "inputs"
  ];

  # A spec is an attrset whose only keys are "follows" and/or "inputs",
  # where every inputs.* value is itself a follows spec.
  # Anything with outPath, lib, packages, … is a direct value, not a spec.
  isSpec =
    v:
    builtins.isAttrs v
    && builtins.all (x: builtins.elem x specKeys) (builtins.attrNames v)
    && (!(v ? inputs) || builtins.all (k: isFollows v.inputs.${k}) (builtins.attrNames v.inputs));

  # Returns the resolved input, or null if any segment in the path is missing.
  walkPath =
    path:
    let
      segs = splitPath path;
      root = allInputs.${builtins.head segs} or null;
    in
    builtins.foldl' (node: seg: if node == null then null else node.inputs.${seg} or null) root (
      builtins.tail segs
    );

  # Per-sub-input override spec from inputs.${hostName}.inputs.${subName}.
  # Works regardless of whether the decl entry also has outPath or other fields.
  overrideSubSpec =
    hostName: subName:
    let
      entry = inputs.${hostName} or null;
      getSubInput = e: if builtins.isAttrs e && e ? inputs then e.inputs.${subName} or null else null;
    in
    getSubInput (if builtins.isFunction entry then (entry sources.${hostName}) else entry);

  # Resolve an inputs entry to an actual input value, or null if unresolvable.
  # Values with outPath but no _type go through mkInput so their flake.nix is loaded.
  resolveInput =
    name: v:
    if builtins.isFunction v then
      resolveInput name (v sources.${name})
    else if isFollows v then
      if v.follows == "" then { } else walkPath v.follows
    else if isSpec v then
      resolvedSources.${name} or { }
    else if v ? outPath && !(v ? _type) then
      mkInput name v
    else
      v;

  resolveSubInput =
    hostName: subName: declaredSpec:
    let
      ov = overrideSubSpec hostName subName;
      spec = if ov != null then ov else declaredSpec;
      walked = if isFollows spec then walkPath spec.follows else null;
      fromAll = allInputs.${subName} or null;
    in
    if isFollows spec then
      if spec.follows == "" then
        { }
      else if walked == null then
        { }
      else
        walked
    else if fromAll == null then
      { }
    else
      fromAll;

  # The attributes a real flake's sourceInfo can carry. Fetcher results (e.g. nixtamal's fetchgit
  # derivations) carry far more; only these may reach a flake input, as in Nix's call-flake.nix.
  flakeSourceInfoKeys = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value = null;
      })
      [
        "outPath"
        "narHash"
        "rev"
        "shortRev"
        "dirtyRev"
        "dirtyShortRev"
        "revCount"
        "lastModified"
        "lastModifiedDate"
        "submodules"
      ]
  );

  # npins names a pin's commit `revision`; a flake input exposes it as `rev`.
  flakeSourceInfo =
    sourceInfo:
    let
      kept =
        builtins.intersectAttrs flakeSourceInfoKeys sourceInfo
        // (
          if !(sourceInfo ? rev) && sourceInfo.revision or null != null then
            { rev = sourceInfo.revision; }
          else
            { }
        );
    in
    if kept ? rev && !(kept ? shortRev) then
      kept // { shortRev = builtins.substring 0 7 kept.rev; }
    else
      kept;

  mkInput =
    name: sourceInfo:
    let
      hasPath = sourceInfo ? outPath;
      isFlake = hasPath && (sourceInfo.flake or true);
      defaultPath = sourceInfo.outPath + "/default.nix";
      defaultNix = import defaultPath;
      defaultArgs = builtins.functionArgs defaultNix;
      hadDefaultValues = builtins.all (withDefault: withDefault) (builtins.attrValues defaultArgs);
      defaultExists = isFlake && builtins.pathExists defaultPath;
      defaultGood = builtins.tryEval (
        defaultExists && builtins.isFunction defaultNix && defaultArgs ? inputsOverrides && hadDefaultValues
      );
      flakePath = sourceInfo.outPath + "/flake.nix";
      flakeExists = isFlake && builtins.pathExists flakePath;
      flakeGood = builtins.tryEval flakeExists;
      # What the loader records about a pin (npins' `version`/`url`/`hash`, niv's `owner`/`branch`,
      # …) stays readable on the input, below its outputs and flake source info. A fetcher
      # derivation (nixtamal) is the exception: its attributes are build internals (#16).
      loaderMetadata = if sourceInfo.type or null == "derivation" then { } else sourceInfo;

    in
    if flakeGood.success && flakeGood.value then
      let
        flake = import flakePath;
        specs = flake.inputs or { };
        # Prefer default.nix if flake inputs specs is empty,
        # unless in a flake evaluation context to avoid loading flake-compat (which would fail for using builtins.currentSystem)
      in
      if (specs == { } && builtins ? currentSystem && defaultGood.success && defaultGood.value) then
        loaderMetadata // mkDefaultWithInputsInput name (flakeSourceInfo sourceInfo) defaultNix
      else
        loaderMetadata // mkFlakeInput name (flakeSourceInfo sourceInfo) flake
    else if defaultGood.success && defaultGood.value then
      loaderMetadata // mkDefaultWithInputsInput name (flakeSourceInfo sourceInfo) defaultNix
    else
      sourceInfo // { inherit sourceInfo; };

  mkDefaultWithInputsInput =
    name: sourceInfo: defaultNix:
    let
      inputsOverrides =
        let
          recFollows =
            let
              # `seen`: the inputs already on this chain, so a follows cycle is refused by name, not a stack overflow.
              follows =
                seen: input:
                isFollows inputs.${input}
                && (
                  let
                    followRoot = builtins.head (builtins.split "/" inputs.${input}.follows);
                    chain = seen ++ [ input ];
                    cycle = builtins.concatStringsSep " -> " (chain ++ [ followRoot ]);
                  in
                  followRoot == name
                  || (
                    inputs ? ${followRoot}
                    && (
                      if builtins.elem followRoot chain then
                        throw "with-inputs: follows cycle: ${cycle}"
                      else
                        follows chain followRoot
                    )
                  )
                );
            in
            [ name ] ++ builtins.filter (follows [ ]) (builtins.attrNames inputs);
        in
        builtins.mapAttrs
          (
            _: value:
            # We wrap overrides in a function so that they are not evaluated eagerly (due to recFollows pruning)
            # when they are them-selves passed further down the dependency tree
            # (which could trigger stackoverflows in complex cases).
            (_: value)
          )
          (
            removeAttrs allInputs recFollows
            // (builtins.mapAttrs (sub: spec: resolveSubInput name sub spec) (inputs.${name}.inputs or { }))
          );
      outputs = defaultNix {
        inherit inputsOverrides;
      };
      self =
        outputs
        // sourceInfo
        // {
          _type = "flake";
          inputs = outputs.inputs or { inherit self; };
          inherit outputs sourceInfo;
        };
    in
    self;

  mkFlakeInput =
    name: sourceInfo: flake:
    let
      specs = flake.inputs or { };
      direct = builtins.mapAttrs (sub: spec: resolveSubInput name sub spec) specs;
      indirect = builtins.mapAttrs (sub: _: resolveSubInput name sub { }) (
        builtins.functionArgs flake.outputs
      );
      inputs = indirect // direct // { inherit self; };
      outputs = flake.outputs inputs;
      self =
        outputs
        // sourceInfo
        // {
          _type = "flake";
          inherit outputs inputs sourceInfo;
        };
    in
    self;

  selfSources = sources.self or { };
  resolvedSources = builtins.mapAttrs mkInput (builtins.removeAttrs sources [ "self" ]);
  # Shallow merge is correct: each key is fully resolved before this point.
  # Sub-input overrides (inputs.foo.inputs.bar.follows) are injected into
  # resolvedSources at resolution time via overrideSubSpec, so no deep merge
  # of resolvedSources and resolvedInputs is needed or wanted.
  resolvedInputs = builtins.mapAttrs resolveInput inputs;
  allInputs = resolvedSources // resolvedInputs;

  __functor =
    allInputs: outputsFn:
    let
      # inputs mirrors a real flake: self is included so modules can access
      # inputs.self.inputs, inputs.self.outputs, and inputs.self.outPath.
      inputs = removeAttrs allInputs [ "__functor" ] // {
        inherit self;
      };
      outputs = outputsFn inputs;
      # self exposes .inputs, .outputs, .sourceInfo and ._type like a real flake self, with all
      # output attributes merged at top level for direct attribute access. As in Nix's
      # call-flake.nix, source info is merged over outputs, so an `outPath` output cannot shadow it.
      self =
        outputs
        // flakeSourceInfo selfSources
        // {
          inherit inputs outputs;
          sourceInfo = flakeSourceInfo selfSources;
          _type = "flake";
        };
    in
    self;

in
allInputs // { inherit __functor; }
