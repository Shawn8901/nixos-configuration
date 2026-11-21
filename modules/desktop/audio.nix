{ config, lib, ... }: {
  options.includes.desktop.audio.enable = lib.mkEnableOption "Enables desktop audio";

  config = lib.mkIf (config.includes.desktop.audio.enable) {

    services.pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      wireplumber.enable = true;
    };

    security = {
      rtkit.enable = true;
      # Upstream pipewire limits for realtime
      # https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/master/meson_options.txt#L342
      pam.loginLimits = [
        {
          domain = "@users";
          item = "rtprio";
          type = "-";
          value = "95";
        }
        {
          domain = "@users";
          item = "memlock";
          type = "-";
          value = "4194304";
        }
        {
          domain = "@users";
          item = "nice";
          type = "-";
          value = "-19";
        }
      ];
    };
  };
}
