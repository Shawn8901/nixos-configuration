{
  preservation = {
    enable = true;
    preserveAt."/persist" = {
      directories = [
        "/etc/NetworkManager/system-connections"
        "/var/lib/bluetooth"
        "/var/lib/cups"
        "/var/lib/libvirt"
        "/var/lib/NetworkManager"
        "/var/lib/prometheus2"
        "/var/lib/upower"
        "/var/lib/mysql"
      ];
    };
  };
}
