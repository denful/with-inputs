let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  locked = lock.nodes.with-inputs.locked;
  with-inputs = builtins.fetchTarball {
    url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.zip";
    sha256 = locked.narHash;
  };
in
(import with-inputs).from.flake ./.
