{ inputs, den, ... }:
{
  imports = [ inputs.den.flakeModule ];

  den.schema.user.classes = [ "homeManager" ];
  den.default.homeManager.home.stateVersion = "25.05";

  den.hosts.x86_64-linux.igloo.users.tux = { };

  den.aspects.igloo.nixos = {
    boot.loader.grub.enable = false;
    fileSystems."/".device = "/dev/noboot";
    fileSystems."/".fsType = "auto";
  };

  den.aspects.tux.includes = [
    den._.define-user
    den._.primary-user
  ];
}
