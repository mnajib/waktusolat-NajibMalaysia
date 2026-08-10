{
  description = "waktusolat-NajibMalaysia: JAKIM prayer-time fetcher daemon + status-bar renderers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          runtimeDeps = with pkgs; [
            curl
            jq
            coreutils
            gawk
            gnused
            util-linux
            python3
          ];

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
              find $out/lib/formatters -name '*.sh' -exec chmod +x {} +
              wrapProgram $out/bin/${name} \
                --set WAKTUSOLAT_LIB_DIR "$out/lib" \
                --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
            '';
          };

          # Helper function to sanitize declaration paths
          #transformFn = opt: opt // {
          #  declarations = map (decl:
          #    let
          #      declStr = toString decl;
          #      matched = builtins.match ".*/[a-z0-9]{32}-source/(.*)" declStr;
          #      relPath =
          #        if matched != null then
          #          builtins.elemAt matched 0
          #        else if pkgs.lib.hasPrefix (toString ./.) declStr then
          #          pkgs.lib.removePrefix "${toString ./.}/" declStr
          #        else
          #          declStr;
          #    in
          #    {
          #      name = relPath;
          #      url = relPath;
          #    }
          #  ) opt.declarations;
          #};
          #
          # Strips the "Declared by:" field completely from generated documentation
          transformFn = opt: opt // {
            declarations = [ ];
          };

          # Evaluated NixOS System instance hosting your module
          #eval = nixpkgs.lib.nixosSystem {
          #  inherit system;
          #  modules = [
          #    self.nixosModules.default
          #  ];
          #};


          # 1. NixOS System evaluation including all NixOS submodules in ./module/
          nixosEval = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              (import ./module/nixos.nix { inherit self; })
              #(import ./module/nixos-aggregator.nix { inherit self; })
              #(import ./module/nixos-client.nix { inherit self; })
            ];
          };

          nixosOptionsDoc = pkgs.nixosOptionsDoc {
            options = nixosEval.options.services.waktusolat;
            warningsAreErrors = false;
            transformOptions = transformFn;
          };

          # 2. Home Manager evaluation for ./module/home-manager.nix
          hmEval = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              (import ./module/home-manager.nix { inherit self; })
              {
                home.stateVersion = "24.05";
                home.username = "najib";
                home.homeDirectory = "/home/najib";
              }
            ];
          };

          hmOptionsDoc = pkgs.nixosOptionsDoc {
            options = hmEval.options.services.waktusolat or hmEval.options.programs.waktusolat;
            warningsAreErrors = false;
            transformOptions = transformFn;
          };


        in
        rec {
          fetchd        = mkScript "waktusolat-fetchd";
          reminder      = mkScript "waktusolat-reminder";
          #render-xmobar = mkScript "waktusolat-render-xmobar";
          #render-waybar = mkScript "waktusolat-render-waybar";
          #cli           = mkScript "waktusolat-cli";

          #docs = pkgs.stdenv.mkDerivation {
          #  name = "waktusolat-options-docs";
          #  src = optionsDoc.optionsCommonMark;
          #  dontUnpack = true;
          #  installPhase = ''
          #    mkdir -p $out
          #    cp $src $out/OPTIONS.md
          #  '';
          #};
          docs = pkgs.stdenv.mkDerivation {
            name = "waktusolat-options-docs";
            nixosSrc = nixosOptionsDoc.optionsCommonMark;
            hmSrc = hmOptionsDoc.optionsCommonMark;
            dontUnpack = true;
            installPhase = ''
              mkdir -p $out
              cp $nixosSrc $out/NIXOS-OPTIONS.md
              cp $hmSrc $out/HOME-MANAGER-OPTIONS.md
            '';
          };

          default = fetchd;
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          runtimeDeps = with pkgs; [ curl jq coreutils gawk gnused util-linux python3 ];
        in
        {
          default = pkgs.mkShell {
            buildInputs = runtimeDeps ++ [
              pkgs.bats
              pkgs.shellcheck

              #
              # To run this script:
              #   update-docs
              #
              #(pkgs.writeShellScriptBin "update-docs" ''
              #  set -e
              #  echo "Building NixOS option documentation..."
              #  nix build .#docs
              #  mkdir -p docs
              #  cp -f result/OPTIONS.md docs/OPTIONS.md
              #  echo "Successfully updated docs/OPTIONS.md!"
              #'')
              #
              (pkgs.writeShellScriptBin "update-docs" ''
                set -e
                echo "Building NixOS and Home Manager option documentation..."
                nix build .#docs
                mkdir -p docs
                cp -f result/NIXOS-OPTIONS.md docs/NIXOS-OPTIONS.md
                cp -f result/HOME-MANAGER-OPTIONS.md docs/HOME-MANAGER-OPTIONS.md
                echo "Successfully updated docs/NIXOS-OPTIONS.md and docs/HOME-MANAGER-OPTIONS.md!"
              '')

            ];
          };
        }
      );

      apps = forAllSystems (system: {
        fetchd = {
          type = "app";
          program = "${self.packages.${system}.fetchd}/bin/waktusolat-fetchd";
        };
        reminder = {
          type = "app";
          program = "${self.packages.${system}.reminder}/bin/waktusolat-reminder";
        };
      });

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          runtimeDeps = with pkgs; [ curl jq coreutils gawk gnused util-linux python3 ];
        in
        {
          bats = pkgs.runCommand "waktusolat-bats-tests" {
            nativeBuildInputs = [ pkgs.bats ] ++ runtimeDeps;
          } ''
            cd ${./.}
            bats tests/
            touch $out
          '';
        }
      );

      # NixOS Module exports (Unified)
      nixosModules = rec {
        default    = import ./module/nixos.nix { inherit self; };
        waktusolat = default;

        #aggregator = default;
        #client     = default;
        #aggregator = import ./module/nixos-aggregator.nix { inherit self; };
        #client     = import ./module/nixos-client.nix { inherit self; };
      };

      # Single-user Home Manager Module
      homeManagerModules = rec {
        default    = import ./module/home-manager.nix { inherit self; };
        waktusolat = default;
      };
    };
}
