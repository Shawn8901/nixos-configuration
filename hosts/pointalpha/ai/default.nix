{ pkgs, ... }:
{

  home-manager.users.shawn = {
    home.packages = with pkgs; [
      opencode
      graphify
    ];
    xdg.configFile."opencode/opencode.jsonc".source = ./opencode.jsonc;
  };

  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-vulkan;
    settings.models-preset = (pkgs.formats.ini { }).generate "models-preset.ini" {
      "qwen3.8-27b" = {
        hf-repo = "unsloth/Qwen3.8-27B-GGUF";
        hf-file = "Qwen3.8-27B-UD-Q3_K_XL.gguf";
        alias = "qwen3.8-27b";
        n-gpu-layers = "99";
        fit = "off";
        ctx-size = toString (128 * 1024);
        flash-attn = "on";
        cache-type-k = "q8_0";
        cache-type-v = "q8_0";
        batch-size = "512";
        ubatch-size = "256";
        parallel = "1";
        no-mmproj = "true";
        jinja = "on";
        reasoning = "on";

        temp = "1.0";
        top-p = "0.95";
        top-k = "20";
        min-p = "0.0";
        presence-penalty = "0.0";
        repeat-penalty = "1.0";
      };
    };
  };
}
