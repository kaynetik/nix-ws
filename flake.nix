{
  description = "NixOS configuration for ksvhost";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
    };
  };

  outputs = inputs@{ nixpkgs, grub2-themes, ... }: let
    # Include secrets.nix even though it's gitignored
    # Use builtins.filterSource to bypass gitignore completely
    nixosSource = builtins.filterSource (path: type:
      let
        baseName = baseNameOf path;
        relPath = nixpkgs.lib.removePrefix (toString ./. + "/") (toString path);
      in
        # Always include secrets.nix (bypasses gitignore)
        baseName == "secrets.nix" ||
        # Include all files in nixos directory
        (nixpkgs.lib.hasPrefix "nixos/" relPath && baseName != ".git") ||
        # Include flake files
        baseName == "flake.nix" || baseName == "flake.lock"
    ) ./.;
  in {
    nixosConfigurations.ksvhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        (nixosSource + "/nixos/configuration.nix")
        grub2-themes.nixosModules.default
      ];
    };
  };
}
