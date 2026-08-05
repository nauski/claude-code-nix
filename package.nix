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
  version = "2.1.222";

  platformMap = {
    "x86_64-linux" = {
      platform = "linux-x64";
      sha256 = "1zy14nil300kbphwlya6pdhkqd3f36rvwz3rhiyb9aivdxdi5036";
    };
    "aarch64-linux" = {
      platform = "linux-arm64";
      sha256 = "1px1ww628vw4z9a32930agjd3v00cryf4vl52n5d0bb59lvcicqv";
    };
    "x86_64-darwin" = {
      platform = "darwin-x64";
      sha256 = "0826ixfvlb96hrpsz1vz2ipa5g2k0s29y8gq3xlllldz8380mp6f";
    };
    "aarch64-darwin" = {
      platform = "darwin-arm64";
      sha256 = "02fxl8lvp89l5dhigj2gmdxl2grwayz38q7ncfp9i6jwwmm0a02w";
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
