{ cfg, ... }:
{
  cfg.monitoree.includes = with cfg.monitoree.provides; [
    vlagent
    vmagent
  ];
}
