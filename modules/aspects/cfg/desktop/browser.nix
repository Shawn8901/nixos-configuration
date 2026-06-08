{ den, inputs, ... }:
{

  flake-file.inputs.firefox-addons = {
    url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  cfg.desktop.provides.browser = {
    includes = [
      (den.provides.unfree [
        "tampermonkey"
        "betterttv"
        "video-downloadhelper"
      ])
    ];

    nixos = {
      environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";
      nixpkgs.overlays = [ inputs.firefox-addons.overlays.default ];
    };

    homeManager =
      {
        pkgs,
        config,
        ...
      }:
      {
        home.packages = [ pkgs.kdePackages.plasma-integration ];
        programs.firefox = {
          enable = true;
          configPath = "${config.xdg.configHome}/mozilla/firefox";
          package = pkgs.firefox;
          profiles."shawn" = {
            extensions = {
              packages = with pkgs.firefox-addons; [
                ublock-origin
                umatrix
                plasma-integration
                h264ify
                bitwarden
                tampermonkey
                betterttv
                video-downloadhelper
              ];
            };
            settings = {
              "app.update.auto" = false;
              "browser.crashReports.unsubmittedCheck.enabled" = false;
              "browser.newtab.preload" = false;
              "browser.newtabpage.activity-stream.enabled" = false;
              "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
              "browser.newtabpage.activity-stream.telemetry" = false;
              "browser.ping-centre.telemetry" = false;
              "browser.safebrowsing.malware.enabled" = true;
              "browser.safebrowsing.phishing.enabled" = true;
              "browser.send_pings" = false;
              "browser.eme.ui.enabled" = true;
              "device.sensors.enabled" = false;
              "dom.battery.enabled" = false;
              "dom.webaudio.enabled" = false;
              "dom.private-attribution.submission.enabled" = false;
              "experiments.enabled" = false;
              "experiments.supported" = false;
              "privacy.donottrackheader.enabled" = true;
              "privacy.firstparty.isolate" = true;
              "privacy.trackingprotection.cryptomining.enabled" = true;
              "privacy.trackingprotection.enabled" = true;
              "privacy.trackingprotection.fingerprinting.enabled" = true;
              "privacy.trackingprotection.pbmode.enabled" = true;
              "privacy.trackingprotection.socialtracking.enabled" = true;
              "security.ssl.errorReporting.automatic" = false;
              "services.sync.engine.addons" = false;
              "services.sync.addons.ignoreUserEnabledChanges" = true;
              "toolkit.telemetry.archive.enabled" = false;
              "toolkit.telemetry.bhrPing.enabled" = false;
              "toolkit.telemetry.enabled" = false;
              "toolkit.telemetry.firstShutdownPing.enabled" = false;
              "toolkit.telemetry.hybridContent.enabled" = false;
              "toolkit.telemetry.newProfilePing.enabled" = false;
              "toolkit.telemetry.reportingpolicy.firstRun" = false;
              "toolkit.telemetry.server" = "";
              "toolkit.telemetry.shutdownPingSender.enabled" = false;
              "toolkit.telemetry.unified" = false;
              "toolkit.telemetry.updatePing.enabled" = false;
              "toolkit.telemetry.pioneer-new-studies-available" = false;
              "gfx.webrender.compositor.force-enabled" = true;
              "browser.cache.disk.enable" = false;
              "browser.cache.memory.enable" = true;
              "extensions.pocket.enabled" = false;
              "extensions.update.enabled" = false;
              "media.ffmpeg.vaapi.enabled" = true;
              "media.ffvpx.enabled" = false;
              "media.navigator.mediadatadecoder_vpx_enabled" = true;
              "media.rdd-vpx.enabled" = false;
              "media.gmp-widevinecdm.enabled" = true;
            };
          };
        };
      };
  };
}
