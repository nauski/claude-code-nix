# Claude Code Package
# 
# This package installs Claude Code with its own Node.js runtime to ensure
# it's always available regardless of project-specific Node.js versions.
#
# Problem: When using devenv, asdf, or other Node.js version managers,
# Claude Code installed via npm might not be available or compatible.
#
# Solution: Install Claude Code through Nix with a bundled Node.js v22 runtime.

{ lib
, stdenv
, nodejs_22
, cacert
, bash
, fetchurl
}:

let
  version = "1.0.100"; # will be updated automatically
  src = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-1.0.100.tgz";
    sha256 = "0wphn9brbvzq6221gq8w8jxxdihsjh8i8pgr4fig2nmraniabz3p"; # will be updated
  };
in

stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  src = src;
  dontUnpack = false;

  # Build dependencies
  nativeBuildInputs = [ 
    nodejs_22   # Use Node.js v22 LTS for compatibility
    cacert      # SSL certificates for npm
  ];
  
  buildPhase = ''
  mkdir -p $out/lib/node_modules/@anthropic-ai

  # npm tarballs unpack into a 'package/' subdirectory
  cp -r . $out/lib/node_modules/@anthropic-ai/claude-code

  mkdir -p $out/bin
  cat > $out/bin/claude <<EOF
  #!${bash}/bin/bash
  NODE_PATH="$out/lib/node_modules" exec ${nodejs_22}/bin/node \
    --no-warnings --enable-source-maps \
    "$out/lib/node_modules/@anthropic-ai/claude-code/cli.js" "\$@"
  EOF
  chmod +x $out/bin/claude
  '';

  meta = with lib; {
    description = "Claude Code - AI coding assistant in your terminal";
    homepage = "https://www.anthropic.com/claude-code";
    license = licenses.unfree;
    platforms = platforms.all;
  };
}
