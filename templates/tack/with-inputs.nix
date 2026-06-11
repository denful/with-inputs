let
  lock = builtins.fromJSON (builtins.readFile ./.tack/pins.lock.json);
  with-inputs = builtins.fetchTarball {
    url = "https://github.com/${lock.with-inputs.owner}/${lock.with-inputs.repo}/archive/${lock.with-inputs.rev}.zip";
    sha256 = lock.with-inputs.narHash;
  };
in
(import with-inputs).from.tack ./.
