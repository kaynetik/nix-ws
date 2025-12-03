{ config, pkgs, ... }:

let
  # Read YAML files from cluster-manifests directory
  traefikChartValues = builtins.readFile ./cluster-manifests/traefik-chart.yaml;
  helmChartConfigTemplate = builtins.readFile ./cluster-manifests/rke2-traefik-config.yaml;

  # Indent the chart values (2 spaces for YAML under valuesContent)
  # Add indentation to all lines including the first one
  indentedValues = "  " + builtins.replaceStrings [ "\n" ] [ "\n  " ] traefikChartValues;

  # Combine the HelmChartConfig template with the indented Traefik chart values
  helmChartConfig = helmChartConfigTemplate + indentedValues;
in
{
  # Traefik configuration via HelmChartConfig
  environment.etc."rancher/rke2/server/manifests/rke2-traefik-config.yaml" = {
    text = helmChartConfig;
    mode = "0644";
  };
}
