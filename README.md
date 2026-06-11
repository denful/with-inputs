<p align="right">
  <a href="https://dendritic.oeiuwq.com/sponsor"><img src="https://img.shields.io/badge/sponsor-vic-white?logo=githubsponsors&logoColor=white&labelColor=%23FF0000" alt="Sponsor Vic"/>
  </a>
  <a href="https://github.com/vic/with-inputs/releases"><img src="https://img.shields.io/github/v/release/vic/with-inputs?style=plastic&logo=github&color=purple"/></a>
  <a href="https://dendritic.oeiuwq.com"> <img src="https://img.shields.io/badge/Dendritic-Nix-informational?logo=nixos&logoColor=white" alt="Dendritic Nix"/> </a>
  <a href="LICENSE"> <img src="https://img.shields.io/github/license/vic/with-inputs" alt="License"/> </a>
  <a href="https://github.com/vic/with-inputs/actions">
  <img src="https://github.com/vic/with-inputs/actions/workflows/test.yml/badge.svg" alt="CI Status"/> </a>
</p>

# with-inputs - A flake-inputs adapter for Nix projects that don't use `flake.nix`.

> with-inputs and [vic](https://bsky.app/profile/oeiuwq.bsky.social)'s [dendritic libs](https://dendritic.oeiuwq.com) made for you with Love++ and AI--. If you like my work, consider [sponsoring](https://dendritic.oeiuwq.com/sponsor)

# with-inputs.nix


Provides exactly the same inputs resolution experience as real Nix flakes —
`follows`, nested `follows`, per-sub-input overrides, `inputs.self`, and
dependency introspection — using pre-fetched sources from npins,
local checkouts, or any other source.

> This library is not an inputs lock mechanism nor an inputs fetcher, for
> those we have plenty of options: npins, niv, lon, unflake, nixlock, nixtamal.

## API

```nix
with-inputs sources follows outputs
```

The `with-inputs` function takes three arguments:

1. already fetched `<name>.outPath` attrs.
2. a function `inputs: specs` for custom follows, input shims or sources overrides.
3. a function `inputs: outputs` like in flakes.

with-inputs does automatic input follows -- having `x.inputs.y` will automatically lookup for a
top-level `y` input. You only need to specify follows for uncommon input names.


## Testimonials 

> Amazing! I just transitioned my main flake to using your with-inputs and npins. It cut my eval times down from 20s to 6s!  
> -- [@theutz](https://github.com/theutz) - [Den](https://github.com/denful/den) core contributor.

> I am very happy to recommend this project. great work @vic!  
> -- [@aanderse](https://github.com/aanderse) - author of [trix](https://github.com/aanderse/trix)


## Examples with different Nix pinning tools

This repo provides several templates using different Nix pinning tools.

Each template has exactly the same code, except for `with-inputs.nix` that
is used to bootstrap from each particular pinning tool.

- [npins](./templates/npins) -- Loads from `./npins`
- [niv](./templates/niv) -- Loads from `nix/sources.nix`
- [lon](./templates/lon) -- Loads from `lon.nix`
- [unflake](./templates/unflake) -- Loads from `unflake.nix`
- [nixtamal](./templates/nixtamal) -- Loads from `nix/tamal`
- [flake](./templates/flake) -- Loads from `flake.lock`
- [tack](./templates/tack) -- Loads from `.tack/pins.toml` + `.tack/pins.lock.json`


## Usage

Download our `default.nix` into your project `./with-inputs.nix`.

```nix
curl https://raw.githubusercontent.com/vic/with-inputs/refs/heads/main/default.nix -o with-inputs.nix
```

Or use npins or `builtins.fetchTarball` with a fixed revision of it. [^output-trick]

```shell
npins add github vic with-inputs
```

```nix
# default.nix
let
   sources = import ./npins; # example with npins. use any other sources.
   with-inputs = import sources.with-inputs sources {
     # keep reading for follows and local inputs
   };

   outputs = inputs: { }; # your flake-like outputs function
in 
with-inputs outputs
```

[^output-trick]: To use the experimental `nix` cli commands, create a `flake.nix` containing only
    ```nix
    { outputs = _: import ./.; }
    ```

### Follows and local checkout overrides

The second argument to `with-inputs` is an attribute set that 
can be used to drive input resolution, for example to use local
checkout or to specify flake-like follows.

See [tests.nix](./tests.nix) and [vic/vix:follows.nix](https://github.com/vic/vix/tree/unflake/follows.nix) for usage examples.

```nix
{
    # Local checkout — loaded as a flake if a flake.nix is present
    mylib.outPath = ./mylib;

    # Local checkout with sub-input overrides applied when loading its flake.nix
    someLib = { outPath = ./someLib; inputs.nixpkgs.follows = "nixpkgs"; };

    # Direct import — value used as-is (function, module result, attrset, etc)
    systems = import ./systems.nix;

    # Top-level follows: alias one input to another
    nixpkgs-stable.follows = "nixpkgs";

    # Nested follows: traverse sub-inputs
    something.follows = "a/b/c";  # → allInputs.a.inputs.b.inputs.c

    # Empty follows: intentionally disconnect an input
    unwanted.follows = "";

    # Per-sub-input follows (mirrors flake.nix `inputs.foo.inputs.bar.follows`)
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Combined: keep the source, override some of its sub-inputs
    someFlake = {
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.utils.follows   = "flake-utils";
    };

    # Takes the original sources.otherFlake and avoids flake call
    otherFlake = source: source // { flake = false; };
}
```

This second argument can also be a function `resolvedInputs -> flakeInputs`, this is
useful for example to shim dependencies like `systems` or  `flake-utils` [`[example]`](https://github.com/vic/vix/blob/unflake/follows.nix).


## `self` shape

All standard `inputs.self.*` patterns work:

```nix
inputs.self                    # the assembled self
inputs.self.inputs             # resolved inputs
inputs.self.inputs.self        # circular, lazy-safe
inputs.self.inputs.nixpkgs     # any resolved input
inputs.self.outputs            # raw outputs attrset
inputs.self.nixosConfigurations  # shorthand for inputs.self.outputs.nixosConfigurations
```

## Resolved flake input shape

Every source with a `flake.nix` is fully resolved into the standard flake shape:

```nix
inputs.nixpkgs.outPath     # store / local path
inputs.nixpkgs.sourceInfo  # raw sourceInfo from sources
inputs.nixpkgs._type       # "flake"
inputs.nixpkgs.inputs      # nixpkgs' own resolved sub-inputs
inputs.nixpkgs.outputs     # nixpkgs' outputs attrset (explicit)
inputs.nixpkgs.lib         # shorthand — same as inputs.nixpkgs.outputs.lib
```

Dependency introspection works just like in flake-parts:

```nix
inputs.someFlake.inputs.nixpkgs          # someFlake's resolved nixpkgs
inputs.someFlake.inputs.nixpkgs.lib      # and its lib, etc.
```

## Unresolvable follows

When a follows target doesn't exist in resolved inputs, the entry becomes
`null`. Sub-flakes that declare that input as required will have their outputs
call skipped (outputs stays `{}`), preventing evaluation errors — exactly like
real flakes when a dependency is absent.

## Input declaration quick reference

| Input declaration | Meaning |
|---|---|
| `foo.outPath = ./path;` | Local checkout, loaded as flake if `flake.nix` present |
| `foo = { outPath = ./path; inputs.dep.follows = "x"; };` | Local checkout with sub-input overrides |
| `foo = import ./path;` | Direct value, used as-is |
| `foo = pinned-source;` | Direct value from npins or similar |
| `b.follows = "a";` | Alias to `allInputs.a` |
| `b.follows = "a/x/y";` | Nested alias via `.inputs.` chain |
| `b.follows = "";` | Empty — resolves to `{}` |
| `a.inputs.b.follows = "x";` | Override sub-input `b` of source `a` |
| `a.inputs.b.follows = "x/y";` | Override with nested follows |
| `a = { inputs.b.follows = "x"; inputs.c.follows = "y"; };` | Meta-spec: keep source, override several sub-inputs |

A value is treated as a **spec** (not a direct value) when its only keys are
`follows` and/or `inputs`, and every `inputs.*` value is a `{ follows = …; }`.
Anything with `outPath`, `lib`, `packages`, `_type`, etc. is a direct value.

## Contributing

PR are welcome, make sure to run tests:

```
nix-unit tests.nix
```
