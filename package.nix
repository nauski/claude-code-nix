# Claude Code Package
#
# Claude Code v2.x ships as a Bun-compiled native binary. The binary has the
# JS bundle appended to the ELF, so we must NOT modify the binary itself
# (autoPatchelfHook breaks Bun's standalone detection).
#
# Instead, we invoke it through the Nix glibc dynamic linker via a wrapper.

{ lib
, stdenv
, glibc
, bash
, fetchurl
}:

let
  version = "2.1.183";

  platformMap = {
    "x86_64-linux" = {
      platform = "linux-x64";
      sha256 = "1ph60qahcm75kl3gqqvl82wz8pr9pk7n582y282yscicrqd310s2";
    };
    "aarch64-linux" = {
      platform = "linux-arm64";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    };
    "x86_64-darwin" = {
      platform = "darwin-x64";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    };
    "aarch64-darwin" = {
      platform = "darwin-arm64";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    };
  };

  platformInfo = platformMap.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  nativeSrc = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code-${platformInfo.platform}/-/claude-code-${platformInfo.platform}-${version}.tgz";
    sha256 = platformInfo.sha256;
  };
in

stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  src = nativeSrc;

  dontFixup = true;

  installPhase =
    if stdenv.hostPlatform.isLinux then ''
      mkdir -p $out/lib $out/bin
      cp claude $out/lib/claude
      chmod +x $out/lib/claude

      cat > $out/bin/claude <<EOF
      #!${bash}/bin/bash
      exec ${glibc}/lib/${if stdenv.hostPlatform.isx86_64 then "ld-linux-x86-64.so.2" else "ld-linux-aarch64.so.1"} --library-path ${glibc}/lib $out/lib/claude "\$@"
      EOF
      chmod +x $out/bin/claude
    '' else ''
      mkdir -p $out/bin
      cp claude $out/bin/claude
      chmod +x $out/bin/claude
    '';

  meta = with lib; {
    description = "Claude Code - AI coding assistant in your terminal";
    homepage = "https://www.anthropic.com/claude-code";
    license = licenses.unfree;
    platforms = builtins.attrNames platformMap;
  };
}
