{
  description = "async-firefly — Ruby gem";

  inputs = {
    nixpkgs.url = "nixpkgs";
    utils.url = "github:numtide/flake-utils";
    mine.url = "github:n-at-han-k/flake.nix";
    mine.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, mine, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = mine.lib.${system};

        # bundlerEnv evaluates the gemspec, so it needs the gemspec and the version it reads.
        # The gemspec parses lib/async/firefly/version.rb rather than requiring it, so only
        # the gemspec itself is copied and no second copy of the library reaches the load path.
        gemspecFiles = pkgs.runCommand "async-firefly-gemspec" { } ''
          mkdir -p $out/lib/async/firefly
          cp ${./async-firefly.gemspec}         $out/async-firefly.gemspec
          cp ${./lib/async/firefly/version.rb}  $out/lib/async/firefly/version.rb
        '';

        gems = pkgs.bundlerEnv {
          name = "async-firefly-gems";
          ruby = pkgs.ruby_3_4;
          gemfile = ./Gemfile;
          lockfile = ./Gemfile.lock;
          gemset = ./gemset.nix;
          extraConfigPaths = [ "${gemspecFiles}/." ];
        };

      in
      {
        devShells.default = lib.mkRubyShell {
          buildInputs = with pkgs; [
            gems
            gems.wrappedRuby
          ];

          shellHook = /* bash */ ''
            export BUNDLE_FORCE_RUBY_PLATFORM=true
            export BUNDLE_GEMFILE="$PWD/Gemfile"
            export BUNDLE_FROZEN=false

            export LANG="''${LANG:-C.UTF-8}"
            export LC_ALL="''${LC_ALL:-$LANG}"

            # This gem is not in the bundle — it is the repository — so put this lib/ and
            # fixtures/ on the load path and let `require "async/firefly"` find the working tree.
            export RUBYLIB="$PWD/lib:$PWD/fixtures''${RUBYLIB:+:$RUBYLIB}"

            # A sibling checkout of async-rest takes precedence, so the gem can be read and
            # changed alongside the client that depends on it.
            if [ -d "$PWD/../async-rest/lib" ]; then
              export RUBYLIB="$PWD/../async-rest/lib:$RUBYLIB"
            fi
          '';
        };
      }
    );
}
