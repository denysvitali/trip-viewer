{ pkgs, lib, ... }:

{
  packages = [
    pkgs.git
    pkgs.flutter
    pkgs.jdk21
  ];

  android = {
    enable = true;
    flutter.enable = true;
  };
  dotenv.disableHint = true;

  env = {
    FLUTTER_ROOT = lib.mkForce "${pkgs.flutter.sdk}";
    DART_SDK = "${pkgs.flutter.sdk}/bin/cache/dart-sdk";
  };

  enterShell = ''
    # Fix missing execute permission on flutter_tester (Nix packaging issue)
    FLUTTER_TESTER="${pkgs.flutter.out}/bin/cache/artifacts/engine/linux-x64/flutter_tester"
    if [ -f "$FLUTTER_TESTER" ] && [ ! -x "$FLUTTER_TESTER" ]; then
      chmod +x "$FLUTTER_TESTER"
    fi

    echo "Flutter version:"
    flutter --version
  '';

  enterTest = ''
    echo "Running tests"
    flutter --version 2>&1 | head -n 1
  '';
}
