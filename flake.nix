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
            python3
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
          disabledEvaluation = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.starCitizenInput.enable = false;
              }
            ];
          };
          guiEvaluation = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.starCitizenInput.enable = true;
                hardware.starCitizenInput.knownManifests = [
                  "3dconnexion-spacemouse-wireless-usb"
                ];
                hardware.starCitizenInput.gui = true;
              }
            ];
          };
          emptyEvaluation = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.starCitizenInput.enable = true;
              }
            ];
          };
          duplicateEvaluation = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.starCitizenInput.enable = true;
                hardware.starCitizenInput.knownManifests = [
                  "3dconnexion-spacemouse-wireless-usb"
                  "3dconnexion-spacemouse-wireless-usb"
                ];
              }
            ];
          };
          x56Evaluation = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.starCitizenInput.enable = true;
                hardware.starCitizenInput.knownManifests = [ "saitek-x56-rhino" ];
              }
            ];
          };
          isIntegrationRulePackage =
            package: builtins.match ".*star-citizen-input-udev-rules.*" (builtins.toString package) != null;
          enabledUdevPackage =
            nixpkgs.lib.findFirst isIntegrationRulePackage null
              moduleEvaluation.config.services.udev.packages;
          x56UdevPackage =
            nixpkgs.lib.findFirst isIntegrationRulePackage null
              x56Evaluation.config.services.udev.packages;
          expectedAllRules = p.pkgs.writeText "expected-star-citizen-input-rules" ''
            SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="0738", ATTRS{idProduct}=="2221", TAG+="uaccess"
            SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="0738", ATTRS{idProduct}=="a221", TAG+="uaccess"
            SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="256f", ATTRS{idProduct}=="c63a", TAG+="uaccess"
          '';
          expectedX56Rules = p.pkgs.writeText "expected-x56-rules" ''
            SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="0738", ATTRS{idProduct}=="2221", TAG+="uaccess"
            SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="0738", ATTRS{idProduct}=="a221", TAG+="uaccess"
          '';
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
                guiAbsent = builtins.toString (
                  !(builtins.elem p.gui moduleEvaluation.config.environment.systemPackages)
                );
                guiPresent = builtins.toString (
                  builtins.elem p.gui guiEvaluation.config.environment.systemPackages
                );
                disabledCliAbsent = builtins.toString (
                  !(builtins.elem p.cli disabledEvaluation.config.environment.systemPackages)
                );
                disabledRuleAbsent = builtins.toString (
                  !(nixpkgs.lib.any isIntegrationRulePackage disabledEvaluation.config.services.udev.packages)
                );
                emptyRejected = builtins.toString (
                  nixpkgs.lib.any (assertion: !assertion.assertion) emptyEvaluation.config.assertions
                );
                duplicateRejected = builtins.toString (
                  nixpkgs.lib.any (assertion: !assertion.assertion) duplicateEvaluation.config.assertions
                );
                noIntegrationServices = builtins.toString (
                  nixpkgs.lib.all (name: !(nixpkgs.lib.hasInfix "starCitizenInput" name)) (
                    builtins.attrNames moduleEvaluation.config.systemd.services
                  )
                );
                noIntegrationUsers = builtins.toString (
                  nixpkgs.lib.all (name: !(nixpkgs.lib.hasInfix "starCitizenInput" name)) (
                    (builtins.attrNames moduleEvaluation.config.users.users)
                    ++ (builtins.attrNames moduleEvaluation.config.users.groups)
                  )
                );
                noIntegrationUserServices = builtins.toString (
                  nixpkgs.lib.all (name: !(nixpkgs.lib.hasInfix "starCitizenInput" name)) (
                    builtins.attrNames moduleEvaluation.config.systemd.user.services
                  )
                );
                noIntegrationTmpfiles = builtins.toString (
                  nixpkgs.lib.all (
                    rule: !(nixpkgs.lib.hasInfix "starCitizenInput" rule)
                  ) moduleEvaluation.config.systemd.tmpfiles.rules
                );
              }
              ''
                test "$udevInstalled" = 1
                test "$cliInstalled" = 1
                test "$diagnosticsEnabled" = 1
                test "$guiAbsent" = 1
                test "$guiPresent" = 1
                test "$disabledCliAbsent" = 1
                test "$disabledRuleAbsent" = 1
                test "$emptyRejected" = 1
                test "$duplicateRejected" = 1
                test "$noIntegrationServices" = 1
                test "$noIntegrationUsers" = 1
                test "$noIntegrationUserServices" = 1
                test "$noIntegrationTmpfiles" = 1
                test -f ${enabledUdevPackage}/lib/udev/rules.d/60-star-citizen-input.rules
                cmp ${expectedAllRules} ${enabledUdevPackage}/lib/udev/rules.d/60-star-citizen-input.rules
                test -f ${x56UdevPackage}/lib/udev/rules.d/60-star-citizen-input.rules
                cmp ${expectedX56Rules} ${x56UdevPackage}/lib/udev/rules.d/60-star-citizen-input.rules
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
                actionlint
                git
                gitleaks
                nixfmt
                ripgrep
                semgrep
                shellcheck
                shfmt
                trivy
                zizmor
              ]);
          };
        }
      );
    };
}
