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
  version = "2.1.285";

  platformMap = {
    "x86_64-linux" = {
      platform = "linux-x64";
      sha256 = "1zhz6k1wi1svx3b5s53s8f0aqiz3k1k14nbypxp26hjz5nzimsiz";
    };
    "aarch64-linux" = {
      platform = "linux-arm64";
      sha256 = "1gscrvd7cxy542bnysd1i6q0i2brvd8mld1as6yn1j5kkm9xr87q";
    };
    "x86_64-darwin" = {
      platform = "darwin-x64";
      sha256 = "1n9anvw59imqg1ip7k20ysn5mvvh4vdh7k14acv37r56jp8m1vb1";
    };
    "aarch64-darwin" = {
      platform = "darwin-arm64";
      sha256 = "0ni3si2hi2ngpd7nsals1iklwy5fxivq30fi000hx6795fm68507";
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
