{
  description = "Safe Linux controller discovery and diagnostics for Star Citizen";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packageSet =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          runtimeTools = with pkgs; [
            acl
            coreutils
            findutils
            gawk
            gnugrep
            gnused
            jq
            libxml2
            systemd
            util-linux
          ];
          cli = pkgs.stdenvNoCC.mkDerivation {
            pname = "starcitizen-linux-input";
            version = "0.1.0";
            src = self;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              runHook preInstall
              install -D -m 0755 bin/sc-input "$out/bin/sc-input"
              install -d "$out/lib/starcitizen-linux-input" "$out/share/starcitizen-linux-input"
              cp -R lib/. "$out/lib/starcitizen-linux-input/"
              cp -R manifests schemas "$out/share/starcitizen-linux-input/"
              wrapProgram "$out/bin/sc-input" \
                --set SC_INPUT_LIB_DIR "$out/lib/starcitizen-linux-input" \
                --set SC_INPUT_SHARE_DIR "$out/share/starcitizen-linux-input" \
                --prefix PATH : "${pkgs.lib.makeBinPath runtimeTools}"
              runHook postInstall
            '';
            meta = {
              description = "Citizen Input Manager command-line backend";
              license = pkgs.lib.licenses.gpl3Only;
              platforms = pkgs.lib.platforms.linux;
              mainProgram = "sc-input";
            };
          };
          gui = pkgs.stdenvNoCC.mkDerivation {
            pname = "starcitizen-linux-input-gui";
            version = "0.1.0";
            src = self;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              runHook preInstall
              install -D -m 0755 bin/sc-input-gui "$out/bin/sc-input-gui"
              wrapProgram "$out/bin/sc-input-gui" \
                --set SC_INPUT_CLI "${cli}/bin/sc-input" \
                --prefix PATH : "${
                  pkgs.lib.makeBinPath [
                    cli
                    pkgs.zenity
                    pkgs.dialog
                  ]
                }"
              runHook postInstall
            '';
            meta = {
              description = "Citizen Input Manager Zenity GUI with a TUI fallback";
              license = pkgs.lib.licenses.gpl3Only;
              platforms = pkgs.lib.platforms.linux;
              mainProgram = "sc-input-gui";
            };
          };
        in
        {
          inherit
            pkgs
            runtimeTools
            cli
            gui
            ;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          p = packageSet system;
        in
        {
          default = p.cli;
          inherit (p) gui;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/sc-input";
          meta.description = "Discover and diagnose Linux controller input";
        };
        gui = {
          type = "app";
          program = "${self.packages.${system}.gui}/bin/sc-input-gui";
          meta.description = "Start Citizen Input Manager";
        };
      });

      nixosModules.default = import ./modules/nixos { inherit self; };

      checks = forAllSystems (
        system:
        let
          p = packageSet system;
          moduleEvaluation = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.starCitizenInput.enable = true;
                hardware.starCitizenInput.knownManifests = [
                  "3dconnexion-spacemouse-wireless-usb"
                  "saitek-x56-rhino"
                ];
              }
            ];
          };
        in
        {
          package = p.cli;
          gui = p.gui;
          tests =
            p.pkgs.runCommand "starcitizen-linux-input-tests"
              {
                nativeBuildInputs =
                  p.runtimeTools
                  ++ (with p.pkgs; [
                    bash
                    git
                    ripgrep
                    shellcheck
                    shfmt
                  ]);
              }
              ''
                cp -R ${self} source
                cd source
                patchShebangs bin tests
                tests/run.sh
                touch "$out"
              '';
          module =
            p.pkgs.runCommand "starcitizen-linux-input-module-check"
              {
                udevInstalled = builtins.toString (
                  nixpkgs.lib.any (
                    package: builtins.match ".*star-citizen-input-udev-rules.*" (builtins.toString package) != null
                  ) moduleEvaluation.config.services.udev.packages
                );
                cliInstalled = builtins.toString (
                  builtins.elem p.cli moduleEvaluation.config.environment.systemPackages
                );
                diagnosticsEnabled = builtins.toString (
                  moduleEvaluation.config.hardware.starCitizenInput.diagnosticTools
                );
              }
              ''
                test "$udevInstalled" = 1
                test "$cliInstalled" = 1
                test "$diagnosticsEnabled" = 1
                touch "$out"
              '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          p = packageSet system;
        in
        {
          default = p.pkgs.mkShell {
            packages =
              p.runtimeTools
              ++ (with p.pkgs; [
                git
                nixfmt
                ripgrep
                shellcheck
                shfmt
              ]);
          };
        }
      );
    };
}
