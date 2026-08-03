{
  description = "waktusolat-NajibMalaysia: JAKIM prayer-time fetcher daemon + status-bar renderers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Common runtime deps shared by fetchd + renderers + cli.
        # curl  : HTTP fetch from JAKIM e-solat API
        # jq    : JSON parsing/building (neutral data file is JSON)
        # util-linux : provides `flock`, used by waktusolat-fetchd's singleton guard
        runtimeDeps = with pkgs; [ curl jq coreutils gawk gnused util-linux ];

        mkScript = name: pkgs.stdenv.mkDerivation {
          pname = name;
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/bin $out/lib
            install -m755 bin/${name} $out/bin/${name}
            cp -r lib/* $out/lib/
            wrapProgram $out/bin/${name} \
              --set WAKTUSOLAT_LIB_DIR "$out/lib" \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
          '';
        };
      in
      {
        packages = {
          fetchd        = mkScript "waktusolat-fetchd";
          render-xmobar = mkScript "waktusolat-render-xmobar";
          render-waybar = mkScript "waktusolat-render-waybar";
          cli           = mkScript "waktusolat-cli";
          default       = self.packages.${system}.fetchd;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps ++ [ pkgs.bats pkgs.shellcheck ];
        };

        apps = {
          fetchd = {
            type = "app";
            program = "${self.packages.${system}.fetchd}/bin/waktusolat-fetchd";
          };
        };

        checks.bats = pkgs.runCommand "waktusolat-bats-tests" {
          nativeBuildInputs = [ pkgs.bats ] ++ runtimeDeps;
        } ''
          cd ${./.}
          bats tests/
          touch $out
        '';
      }
    ) // {
      #
      # CHANGED (multi-host support): the per-user home-manager module is
      # superseded by these two NixOS system modules for any host that
      # needs to share data across local users and/or participate in the
      # aggregator/client split. It's kept below for single-user hosts that
      # don't need any of that, but new setups should prefer the NixOS
      # modules.
      #
      # For single-user on single-host
      #homeManagerModules.default = import ./module/home-manager.nix self;
      homeManagerModules.default = import ./module/home-manager.nix { inherit self; };
      #
      # Support for multi-user and multi-host
      #nixosModules.aggregator = import ./module/nixos-aggregator.nix self;
      #nixosModules.client = import ./module/nixos-client.nix self;
      nixosModules.aggregator = import ./module/nixos-aggregator.nix { inherit self; };
      nixosModules.client = import ./module/nixos-client.nix { inherit self; };
    };
}
