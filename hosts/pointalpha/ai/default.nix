{
  config,
  pkgs,
  lib,
  ...
}:
let
  contextLength = 128 * 1024;
in
{
  sops.secrets = {
    grafana-service-account-token.owner = "shawn";
  };

  home-manager.users.shawn = {

    home.packages = with pkgs; [
      graphify
    ];
    programs.mcp = {
      enable = true;
      servers = {
        grafana = {
          command = (lib.getExe pkgs.mcp-grafana);
          env = {
            GRAFANA_URL = "https://grafana.pointjig.de";
            GRAFANA_SERVICE_ACCOUNT_TOKEN.file = config.sops.secrets.grafana-service-account-token.path;
          };
        };
        context7.command = (lib.getExe pkgs.context7-mcp);
      };
    };

    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      settings = {
        model = "llama-cpp/qwen3.8-27b";
        "plugins" = [
          "opencode-mem@latest"
          "@dietrichgebert/ponytail"
        ];
        providers.llama-cpp = {
          name = "llama.cpp";
          package = "@opencode/ai/providers/openai-compatible";
          settings = {
            baseURL = "http://127.0.0.1:8080/";
            apiKey = "sk-dummy";
          };
          models."qwen3.8-27b" = {
            modelID = "qwen3.8-27b";
            name = "Qwen3.8-27B-UD-Q3_K_XL";
            capabilities = {
              tools = true;
              input = [ "text" ];
              output = [ "text" ];
            };
            limit = {
              context = contextLength;
              output = 8192;
            };
          };
        };
      };
    };
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
        ctx-size = toString contextLength;
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
