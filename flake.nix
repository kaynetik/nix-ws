{
  description = "NixOS configuration for ksvhost";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
    };
  };

  outputs = inputs@{ nixpkgs, grub2-themes, ... }: {
    nixosConfigurations.ksvhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./nixos/configuration.nix
        grub2-themes.nixosModules.default
      ];
    };
  };
}
