# RUN WITH: nix-unit ./tests.nix
let
  with-inputs = import ./default.nix;

  # Fake sourceInfo: has outPath but no real flake.nix → passes through mkInput unchanged.
  mkSrc = outPath: { inherit outPath; };

  # Fake pre-resolved flake input with .inputs (simulates dependency introspection).
  mkFlake = inputs: outputs: { inherit inputs outputs; };

  npins = import ./fixtures/npins;
in
{
  # ── Sources ────────────────────────────────────────────────────────────────

  "test source outPath preserved" = {
    expr = (with-inputs { foo = mkSrc "/foo"; } { }).foo.outPath;
    expected = "/foo";
  };

  # ── Direct decl values ─────────────────────────────────────────────────────

  "test local checkout outPath preserved" = {
    # someLib.outPath = ./path → goes through mkInput (load flake if present);
    # since /fake has no flake.nix the sourceInfo passes through unchanged.
    expr = (with-inputs { } { someLib.outPath = "/fake"; }).someLib.outPath;
    expected = "/fake";
  };

  "test local checkout with sub-input follows wired" = {
    # a = { outPath = ./path; inputs.nixpkgs.follows = "nixpkgs"; }
    # Loads the local flake.nix and redirects its nixpkgs sub-input to ours.
    # Verifies via the flake's outputs that the right nixpkgs was received.
    expr =
      let
        result = with-inputs { nixpkgs = mkSrc "/our-nixpkgs"; } {
          mylib = {
            outPath = ./fixtures/fake-flake;
            inputs.nixpkgs.follows = "nixpkgs";
          };
        };
      in
      result.mylib.usedNixpkgs.outPath;
    expected = "/our-nixpkgs";
  };

  "test direct import without outPath" = {
    # someLib = import ./path → the value is used as-is (no outPath, not a spec).
    expr =
      (with-inputs { } {
        someLib = {
          lib = "hello";
        };
      }).someLib.lib;
    expected = "hello";
  };

  "test inputs replaces source" = {
    expr = (with-inputs { foo = mkSrc "/original"; } { foo = mkSrc "/override"; }).foo.outPath;
    expected = "/override";
  };

  "test pre-with-inputsd flake input passes through unchanged" = {
    # A value already shaped as a flake input (_type present) is used as-is.
    expr =
      let
        flakeInput = {
          outPath = "/x";
          _type = "flake";
          inputs = { };
          outputs = {
            lib = "hello";
          };
        };
        result = with-inputs { } { x = flakeInput; };
      in
      result.x.outputs.lib;
    expected = "hello";
  };

  # ── Top-level follows ──────────────────────────────────────────────────────

  "test follows aliases source" = {
    expr = (with-inputs { a = mkSrc "/a"; } { b.follows = "a"; }).b.outPath;
    expected = "/a";
  };

  "test follows aliases decl value" = {
    expr =
      (with-inputs { } {
        a = mkSrc "/a";
        b.follows = "a";
      }).b.outPath;
    expected = "/a";
  };

  "test follows chain" = {
    # c.follows = "b" where b.follows = "a"
    expr =
      let
        result = with-inputs { } {
          a = mkSrc "/a";
          b.follows = "a";
          c.follows = "b";
        };
      in
      result.c.outPath;
    expected = "/a";
  };

  "test nested follows one level" = {
    # b.follows = "a/x" → allInputs.a.inputs.x
    expr =
      let
        result = with-inputs { } {
          a = mkFlake { x = mkSrc "/x"; } { };
          b.follows = "a/x";
        };
      in
      result.b.outPath;
    expected = "/x";
  };

  "test nested follows two levels" = {
    # b.follows = "a/x/y" → allInputs.a.inputs.x.inputs.y
    expr =
      let
        result = with-inputs { } {
          a = mkFlake { x = mkFlake { y = mkSrc "/y"; } { }; } { };
          b.follows = "a/x/y";
        };
      in
      result.b.outPath;
    expected = "/y";
  };

  "test empty follows yields empty attrset" = {
    # b.follows = "" → intentionally disconnected, with-inputss to {}
    expr = (with-inputs { } { b.follows = ""; }).b;
    expected = { };
  };

  "test missing follows target is null" = {
    # b.follows = "nonexistent" → null (guards sub-flake output evaluation)
    expr = (with-inputs { } { b.follows = "nonexistent"; }).b == null;
    expected = true;
  };

  "test missing nested follows path is null" = {
    expr =
      let
        result = with-inputs { } {
          a = mkFlake { } { };
          b.follows = "a/missing";
        };
      in
      result.b == null;
    expected = true;
  };

  # ── Per-sub-input follows (a.inputs.b.follows = "...") ─────────────────────

  "test home-manager nixpkgs follows uses host nixpkgs" = {
    # The canonical idiom: home-manager.inputs.nixpkgs.follows = "nixpkgs".
    # Ensures home-manager uses the same nixpkgs as the host, not its own pin.
    # The fixture flake.nix declares inputs.nixpkgs and exposes it via usedNixpkgs.
    expr =
      let
        result =
          with-inputs
            {
              nixpkgs = mkSrc "/our-nixpkgs";
              home-manager = mkSrc ./fixtures/fake-flake;
            }
            {
              home-manager.inputs.nixpkgs.follows = "nixpkgs";
            };
      in
      result.home-manager.usedNixpkgs.outPath;
    expected = "/our-nixpkgs";
  };

  "test source kept when only sub-input spec declared" = {
    # inputs.a = { inputs.dep.follows = "dep"; } is a pure meta-spec:
    # no outPath means keep the source from sources, apply the sub-input override.
    expr =
      let
        result =
          with-inputs
            {
              nixpkgs = mkSrc "/our-nixpkgs";
              mylib = mkSrc ./fixtures/fake-flake;
            }
            {
              mylib.inputs.nixpkgs.follows = "nixpkgs";
            };
      in
      result.mylib.usedNixpkgs.outPath;
    expected = "/our-nixpkgs";
  };

  "test sub-input follows missing target skips outputs" = {
    # utils.follows = "flake-utils" but flake-utils not pinned → utils = null.
    # A real sub-flake needing 'utils' would have inputsOk=false → outputs={}.
    expr =
      (with-inputs { nixpkgs = mkSrc "/nixpkgs"; } { utils.follows = "flake-utils"; }).utils == null;
    expected = true;
  };

  "test sub-input nested follows" = {
    # home-manager.inputs.nixpkgs.follows = "inputs/nixpkgs" → traverses inputs.inputs.nixpkgs
    expr =
      let
        result =
          with-inputs
            {
              inputs = mkFlake { nixpkgs = mkSrc "/nested-nixpkgs"; } { };
              home-manager = mkSrc ./fixtures/fake-flake;
            }
            {
              home-manager.inputs.nixpkgs.follows = "inputs/nixpkgs";
            };
      in
      result.home-manager.usedNixpkgs.outPath;
    expected = "/nested-nixpkgs";
  };

  # ── Functor / self ─────────────────────────────────────────────────────────

  "test outputs function receives with-inputsd inputs" = {
    expr =
      (with-inputs { foo = mkSrc "/foo"; } { } (inputs: {
        v = inputs.foo.outPath;
      })).v;
    expected = "/foo";
  };

  "test outputs function receives inputs.self" = {
    expr =
      (with-inputs { } { } (inputs: {
        has = inputs ? self;
      })).has;
    expected = true;
  };

  "test self.inputs is the with-inputsd inputs attrset" = {
    expr = (with-inputs { foo = mkSrc "/foo"; } { } (_: { })).inputs.foo.outPath;
    expected = "/foo";
  };

  "test self.outputs is the raw outputs attrset" = {
    expr =
      (with-inputs { } { } (_: {
        marker = "hello";
      })).outputs.marker;
    expected = "hello";
  };

  "test output attrs merged on self" = {
    # inputs.self.packages ≡ inputs.self.outputs.packages
    expr =
      (with-inputs { } { } (_: {
        packages.default = "pkg";
      })).packages.default;
    expected = "pkg";
  };

  "test self.inputs.self is self" = {
    # Circular but lazy-safe: inputs.self.inputs.self == inputs.self
    expr =
      let
        result = with-inputs { } { } (_: { });
      in
      result.inputs.self == result;
    expected = true;
  };

  # ── Input Overrides Function ────────────────────────────────────────────────
  "test input function overrides foo" = {
    expr =
      (with-inputs { foo = mkSrc "/foo"; } (inputs: {
        foo = mkSrc "/bar";
      })).foo.outPath;
    expected = "/bar";
  };

  "test input function overrides and uses foo" = {
    expr =
      (with-inputs
        {
          foo = mkSrc "/foo";
          bar = mkSrc "/bar";
        }
        (inputs: {
          foo = mkSrc "${inputs.bar}/bar";
        })
      ).foo.outPath;
    expected = "/bar/bar";
  };

  # ── Dependency introspection ────────────────────────────────────────────────

  "test access sub-flake inputs" = {
    # inputs.someFlake.inputs.dep — traverse a dependency's own inputs
    expr = (with-inputs { } { a = mkFlake { dep = mkSrc "/dep"; } { }; }).a.inputs.dep.outPath;
    expected = "/dep";
  };

  "test access sub-flake outputs" = {
    # inputs.someFlake.outputs.lib — explicit outputs access
    expr = (with-inputs { } { a = mkFlake { } { lib = "mylib"; }; }).a.outputs.lib;
    expected = "mylib";
  };

  "test sub-flake output attrs merged at top level" = {
    # inputs.someFlake.lib ≡ inputs.someFlake.outputs.lib
    expr =
      let
        flakeInput = {
          lib = "mylib";
          outputs = {
            lib = "mylib";
          };
          inputs = { };
          _type = "flake";
          outPath = "/x";
        };
      in
      (with-inputs { } { a = flakeInput; }).a.lib;
    expected = "mylib";
  };

  "test npins nix-maid nixosModules output is readable" = {
    expr =
      (with-inputs npins { } (inputs: {
        check = inputs ? nix-maid.nixosModules.default;
      })).check;
    expected = true;
  };

  "test npins home-manager nixosModules output is readable" = {
    expr =
      (with-inputs npins { } (inputs: {
        check = inputs ? home-manager.nixosModules.default;
      })).check;
    expected = true;
  };

  "test npins hjem nixosModules output is readable" = {
    expr =
      (with-inputs npins { } (inputs: {
        check = inputs ? hjem.nixosModules.default;
      })).check;
    expected = true;
  };

  "test npins hjem->smfh->nixpkgs dependency is followed" = {
    expr =
      (with-inputs npins { } (inputs: {
        check = inputs.hjem.inputs.smfh.inputs.nixpkgs.sourceInfo.outPath;
      })).check;
    expected = npins.nixpkgs.outPath;
  };

}
