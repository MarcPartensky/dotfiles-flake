{ my-config, zfs-root, inputs, pkgs, lib, ... }: {
  # load module config to top-level configuration
  inherit my-config zfs-root;

  # Let 'nixos-version --json' know about the Git revision
  # of this flake.
  system.configurationRevision = if (inputs.self ? rev) then
    inputs.self.rev
  else
    throw "refuse to build: git tree is dirty";

  system.stateVersion = "22.11";

  # Enable NetworkManager for wireless networking,
  # You can configure networking with "nmtui" command.
  # networking.useDHCP = true;
  networking.networkmanager.enable = true;
  networking.wireless.iwd.enable = true;
  networking.networkmanager.wifi.backend = "iwd";

  users.users = {
    root = {
      initialHashedPassword = "$6$0QAYnBqAJtqB12p3$2lb7rAS2sYw49GUJt0L0bAEpZJSv4HZARQjlbYPhexSmeRB71IRMBzXjf3b4rX6fuDxOuDLydP/Kni9uraS5j/";
      openssh.authorizedKeys.keys = [ "sshKey_placeholder" ];
    };
    marc = {
      isNormalUser = true;
      home = "/home/marc";
      description = "Marc Partensky";
      extraGroups = ["wheel" "networkmanager"];
      # openssh.authorizedKeys.keys = 
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
    # "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
  ];

  services.openssh = {
    enable = lib.mkDefault true;
    settings = { PasswordAuthentication = lib.mkDefault false; };
  };

  # services.iwd.enable = true;

  boot.zfs.forceImportRoot = lib.mkDefault false;

  nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];

  programs.git.enable = true;

  security = {
    doas.enable = lib.mkDefault true;
    sudo.enable = lib.mkDefault false;
  };

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      mg # emacs-like editor
      jq # other programs
    ;
  };
}
