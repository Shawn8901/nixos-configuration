{
  preservation = {
    enable = true;
    preserveAt."/persist" = {
      directories = [
        "/var/lib/alsa"
        "/var/lib/dovecot"
        "/var/lib/hydra"
        "/var/lib/immich"
        "/var/lib/nextcloud"
        "/var/lib/openarchiver"
        "/var/lib/postfix"
        {
          directory = "/var/lib/private/meilisearch";
          mode = "0700";
        }
        {
          directory = "/var/lib/private/tika";
          mode = "0700";
        }
        "/var/lib/rspamd"
        "/var/lib/samba"
      ];
    };
  };
}
