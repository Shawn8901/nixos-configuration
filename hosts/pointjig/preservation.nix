{
  preservation = {
    enable = true;
    preserveAt."/persist" = {
      directories = [
        "/var/lib/dovecot"
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
        "/var/lib/vaultwarden"
        "/var/lib/valheim"
      ];
    };
  };
}
