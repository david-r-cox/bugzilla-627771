{
 description = "Firefox with custom gradient.glsl and renderer patches";
 inputs = {
   nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
   flake-utils.url = "github:numtide/flake-utils";
 };
 outputs = { self, nixpkgs, flake-utils }:
   flake-utils.lib.eachDefaultSystem (system:
     let
       pkgs = nixpkgs.legacyPackages.${system};

       # Patch creation functions
       createGradientPatch = newFile: pkgs.runCommand "gradient.patch" { } ''
         mkdir -p temp/a/gfx/wr/webrender/res temp/b/gfx/wr/webrender/res
         touch temp/a/gfx/wr/webrender/res/gradient.glsl
         cp ${newFile} temp/b/gfx/wr/webrender/res/gradient.glsl
         ${pkgs.diffutils}/bin/diff -Naur temp/a/gfx/wr/webrender/res/gradient.glsl temp/b/gfx/wr/webrender/res/gradient.glsl > $out || [ $? -eq 1 ]
       '';

       createRendererPatch = newFile: pkgs.runCommand "renderer.patch" { } ''
         mkdir -p temp/a/gfx/wr/webrender/src/renderer temp/b/gfx/wr/webrender/src/renderer
         touch temp/a/gfx/wr/webrender/src/renderer/mod.rs
         cp ${newFile} temp/b/gfx/wr/webrender/src/renderer/mod.rs
         ${pkgs.diffutils}/bin/diff -Naur temp/a/gfx/wr/webrender/src/renderer/mod.rs temp/b/gfx/wr/webrender/src/renderer/mod.rs > $out || [ $? -eq 1 ]
       '';


firefox-patched = pkgs.wrapFirefox (
  (pkgs.firefox-unwrapped.override {
    stdenv = pkgs.stdenvNoCC.override {
      cc = pkgs.ccacheWrapper.override {
        cc = pkgs.llvmPackages_16.clang;
        extraConfig = ''
          export CCACHE_DIR="/tmp/ccache"
          export CCACHE_COMPILER_TYPE=clang
          export CCACHE_SLOPPINESS=random_seed
          export CCACHE_NODIRECT=true
          export CCACHE_BASEDIR=/build
          export CCACHE_MAXSIZE=10G
          export CCACHE_UMASK=000
        '';
      };
    };
  }).overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      (createGradientPatch ./gradient.glsl)
      (createRendererPatch ./mod.rs)
    ];

    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [
      pkgs.ccache
      pkgs.which
    ];

    configureFlags = (oldAttrs.configureFlags or []) ++ [
      "--with-ccache=${pkgs.ccache}/bin/ccache"
    ];

    preBuildHooks = (oldAttrs.preBuildHooks or []) ++ [
      ''
        export CCACHE_DIR="/tmp/ccache"
        export CCACHE_COMPILER_TYPE=clang
        export CCACHE_SLOPPINESS=random_seed
        export CCACHE_NODIRECT=true
        export CCACHE_BASEDIR=/build
        export CCACHE_MAXSIZE=10G
        export CCACHE_UMASK=000
      ''
    ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      # Export ccache vars again to be sure
      export CCACHE_DIR="/tmp/ccache"
      export CCACHE_COMPILER_TYPE=clang
      export CCACHE_SLOPPINESS=random_seed
      export CCACHE_NODIRECT=true
      export CCACHE_BASEDIR=/build
      export CCACHE_MAXSIZE=10G
      export CCACHE_UMASK=000

      echo "Ccache config:"
      ${pkgs.ccache}/bin/ccache -p
      echo "Ccache stats:"
      ${pkgs.ccache}/bin/ccache -s
    '';
  })
) { };
     in
     {
       packages = {
         firefox = firefox-patched;
         default = firefox-patched;
       };
     }
   );
}

# Note on ccache:
# This flake works with the following nixos system config:
#      programs.ccache = {
#        enable = true;
#        packageNames = [ "firefox" ];
#        cacheDir = "/tmp/ccache";
#      };
#
#      nix.settings = {
#        extra-sandbox-paths = [
#          "/tmp/ccache"
#        ];
#        sandbox = true;
#      };
#
#      nixpkgs.overlays = [
#        (self: super: {
#          ccacheWrapper = super.ccacheWrapper.override {
#            extraConfig = ''
#    	  export CCACHE_DEBUG=1
#    	  export CCACHE_DEBUGDIR=/tmp/ccache/log
#              export CCACHE_DIR="/tmp/ccache"
#              export CCACHE_COMPRESS=1
#              export CCACHE_UMASK=002
#              export CCACHE_COMPILER_TYPE=clang
#              export CCACHE_SLOPPINESS=random_seed
#              export CCACHE_NODIRECT=true
#              export CCACHE_BASEDIR=/build
#              export CCACHE_MAXSIZE=10G
#              export CCACHE_VERBOSE=1
#            '';
#          };
#        })
#      ];
#
#
# And the following home-manager config:
#      nix.settings = {
#        extra-sandbox-paths = [
#          "/tmp/ccache"
#        ];
#        sandbox = true;
#      };
#
# I'm not sure if all of these configs are required.
