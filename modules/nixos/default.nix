{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.starCitizenInput;
  knownManifestPaths = {
    "3dconnexion-spacemouse-wireless-usb" = ../../manifests/3dconnexion/spacemouse-wireless-usb.json;
    "saitek-x56-rhino" = ../../manifests/saitek/x56-rhino.json;
  };
  readManifest = path: builtins.fromJSON (builtins.readFile path);
  manifests =
    (map (id: readManifest knownManifestPaths.${id}) cfg.knownManifests)
    ++ (map readManifest cfg.manifestFiles);
  safeId = value: builtins.match "[a-z0-9]+([.-][a-z0-9]+)*" value != null;
  safeHex = value: builtins.match "[0-9a-f]{4}" value != null;
  exactKeys =
    value: allowed:
    builtins.isAttrs value
    && lib.all (key: builtins.elem key allowed) (builtins.attrNames value)
    && lib.all (key: builtins.hasAttr key value) allowed;
  noAbsoluteStrings =
    value:
    if builtins.isString value then
      builtins.stringLength value == 0 || builtins.substring 0 1 value != "/"
    else if builtins.isList value then
      lib.all noAbsoluteStrings value
    else if builtins.isAttrs value then
      lib.all noAbsoluteStrings (builtins.attrValues value)
    else
      true;
  statusValid =
    value:
    builtins.elem value [
      "tested"
      "reported"
      "candidate"
      "unverified"
      "unsupported"
    ];
  manifestValid =
    manifest:
    let
      accessPolicy = manifest.accessPolicy or { };
      support = manifest.support or { };
      devices = manifest.devices or [ ];
      references = manifest.references or [ ];
      roles = map (device: device.role or "") devices;
    in
    exactKeys manifest [
      "$schema"
      "schemaVersion"
      "id"
      "displayName"
      "description"
      "devices"
      "accessPolicy"
      "support"
      "references"
    ]
    && (manifest.schemaVersion or null) == 1
    && safeId (manifest.id or "")
    && builtins.isString (manifest.displayName or null)
    && builtins.stringLength (manifest.displayName or "") > 0
    && builtins.isString (manifest.description or null)
    && devices != [ ]
    && lib.all (
      device:
      exactKeys device [
        "role"
        "vendorId"
        "productId"
        "transport"
        "expectedNodes"
      ]
      && safeId (device.role or "")
      && safeHex (device.vendorId or "")
      && safeHex (device.productId or "")
      && (device.transport or "") == "usb"
      && (device.expectedNodes or [ ]) != [ ]
      && lib.all (
        node:
        builtins.elem node [
          "hidraw"
          "event"
          "joystick"
        ]
      ) (device.expectedNodes or [ ])
      &&
        builtins.length (device.expectedNodes or [ ])
        == builtins.length (lib.unique (device.expectedNodes or [ ]))
    ) devices
    && builtins.length roles == builtins.length (lib.unique roles)
    && exactKeys accessPolicy [
      "hidraw"
      "input"
    ]
    && (accessPolicy.hidraw or "") == "uaccess"
    && (accessPolicy.input or "") == "verify-only"
    && exactKeys support [
      "nativeLinux"
      "hidrawUaccess"
      "wine"
      "starCitizen"
    ]
    && lib.all statusValid (builtins.attrValues support)
    && builtins.isList references
    && lib.all (
      reference:
      exactKeys reference [
        "type"
        "url"
      ]
      && builtins.elem (reference.type or "") [
        "repository"
        "issue"
        "documentation"
      ]
      && builtins.isString (reference.url or null)
      && builtins.match "https://.*" (reference.url or "") != null
    ) references
    && noAbsoluteStrings manifest;
  pairs = lib.unique (
    lib.concatMap (
      manifest: map (device: { inherit (device) vendorId productId; }) manifest.devices
    ) manifests
  );
  sortedPairs = lib.sort (
    left: right:
    if left.vendorId == right.vendorId then
      left.productId < right.productId
    else
      left.vendorId < right.vendorId
  ) pairs;
  rules = lib.concatMapStrings (
    pair:
    ''SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="${pair.vendorId}", ATTRS{idProduct}=="${pair.productId}", TAG+="uaccess"\n''
  ) sortedPairs;
  udevPackage = pkgs.writeTextFile {
    name = "star-citizen-input-udev-rules";
    destination = "/lib/udev/rules.d/60-star-citizen-input.rules";
    text = rules;
  };
  cliPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
  guiPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.gui;
in
{
  options.hardware.starCitizenInput = {
    enable = lib.mkEnableOption "safe Star Citizen controller discovery and scoped HIDRAW access";

    knownManifests = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (builtins.attrNames knownManifestPaths));
      default = [ ];
      description = "Known device manifests whose scoped HIDRAW rules are enabled.";
    };

    manifestFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Additional local schema-version-1 JSON manifest files.";
    };

    diagnosticTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install optional read-only USB and ACL diagnostic utilities when enabled.";
    };

    gui = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install the Citizen Input Manager GUI and TUI fallback.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all manifestValid manifests;
        message = "All hardware.starCitizenInput manifests must satisfy the safe schema-version-1 subset.";
      }
    ];
    services.udev.packages = [ udevPackage ];
    environment.systemPackages = [
      cliPackage
    ]
    ++ lib.optional cfg.gui guiPackage
    ++ lib.optionals cfg.diagnosticTools [
      pkgs.acl
      pkgs.usbutils
    ];
  };
}
