{
  outputs =
    _:
    (import ./.)
    // {
      templates = {
        npins.description = "npins";
        npins.path = ./templates/npins;

        niv.description = "niv";
        niv.path = ./templates/niv;

        lon.description = "lon";
        lon.path = ./templates/lon;

        unflake.description = "unflake";
        unflake.path = ./templates/unflake;

        flake.description = "flake";
        flake.path = ./templates/flake;

        nixtamal.description = "nixtamal";
        nixtamal.path = ./templates/nixtamal;
      };
    };
}
