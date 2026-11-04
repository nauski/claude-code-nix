# Claude Code Package
#
# Claude Code v2.x ships as a Bun-compiled native binary. The binary has the
# JS bundle appended to the ELF after the last section, so heavyweight ELF
# rewriting (autoPatchelfHook: rpath rewrite + strip + section shuffling)
# corrupts Bun's appended-payload detection and must be avoided.
#
# A *surgical* `patchelf --set-interpreter` (changing only PT_INTERP to the Nix
# glibc loader) leaves the appended payload untouched and is verified safe, so
# we run the binary natively instead of through a loader-exec wrapper.
#
# Running natively matters: the binary's bundled ripgrep/find/grep helpers and
# Claude's shell integration re-invoke `process.execPath` (= /proc/self/exe).
# A loader-exec wrapper (or nix-ld, which execve's the real loader) makes that
# path the dynamic linker, so the re-invocation runs the loader as `ugrep -G …`
# and dies with "-G: error while loading shared libraries". Patching the
# interpreter keeps /proc/self/exe pointed at the binary, so re-dispatch works.

{ lib
, stdenv
, glibc
, patchelf
, fetchurl
}:

let
  version = "2.1.318";

  platformMap = {
    "x86_64-linux" = {
      platform = "linux-x64";
      sha256 = "0ksmklpyizh0mvf926b8cbqpmxcpxacvsm8rpdcjkggms0xmwk9a";
    };
    "aarch64-linux" = {
      platform = "linux-arm64";
      sha256 = "12kc86pgriabgxphkpp6cpfyq1j9jb213h6iqv5si0lpdsig97s2";
    };
    "x86_64-darwin" = {
      platform = "darwin-x64";
      sha256 = "10kppw676kzxm37qgw50j6kvfmgxp6ig7xn9i3xnrm2vj4b6sfh7";
    };
    "aarch64-darwin" = {
      platform = "darwin-arm64";
      sha256 = "1flnbbkj6zv6k3i6krl7caf9anmahkkp0dr66gysd5mx9fw8d9h2";
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

  # Skip the default fixup phase: stripping and automatic ELF rewriting would
  # corrupt the Bun payload appended to the binary. We do the one safe edit
  # (set-interpreter) by hand below.
  dontFixup = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ patchelf ];

  installPhase =
    if stdenv.hostPlatform.isLinux then ''
      mkdir -p $out/bin
      cp claude $out/bin/claude
      chmod +w $out/bin/claude

      # Point only PT_INTERP at the Nix glibc loader; leave everything else
      # (including the appended Bun payload) byte-for-byte intact. All NEEDED
      # libs are plain glibc and resolve via the loader's default search path,
      # so no RPATH is required.
      patchelf --set-interpreter \
        ${glibc}/lib/${if stdenv.hostPlatform.isx86_64 then "ld-linux-x86-64.so.2" else "ld-linux-aarch64.so.1"} \
        $out/bin/claude

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
