{
  preservation = {
    enable = true;
    preserveAt."/persist" = {
      directories = [
        "/var/lib/thread"
        {
          directory = "/var/lib/hass";
          user = "hass";
          group = "hass";
        }
        {
          directory = "/var/lib/private/matterjs-server";
          user = "nobody";
          group = "nogroup";
          mode = "0700";
        }
      ];
    };
  };
}
