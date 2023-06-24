# #
##
##  per-host configuration for exampleHost
##
##

{ system, pkgs, ... }: {
  inherit pkgs system;
  zfs-root = {
    boot = {
      devNodes = "/dev/";
      bootDevices = [  "nvme0n1" ];
      immutable = false;
      availableKernelModules = [  "nvme" "xhci_pci" "usbhid" "usb_storage" "sd_mod" ];
      removableEfi = true;
      kernelParams = [ ];
      sshUnlock = {
        # read sshUnlock.txt file.
        enable = false;
        authorizedKeys = [ ];
      };
    };
    networking = {
      # read changeHostName.txt file.
      hostName = "tower";
      timeZone = "Europe/Paris";
      hostId = "97a4a6a0";
    };
  };

  # To add more options to per-host configuration, you can create a
  # custom configuration module, then add it here.
  my-config = {
    # Enable custom gnome desktop on exampleHost
    template.desktop.gnome.enable = false;
  };
}
