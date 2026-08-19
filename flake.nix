{
  description = "ORNL portable data engineering toolkit";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        # Pin the Rust toolchain — adjust channel/version as needed
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };

        # Python version to match what OLCF miniforge3 provides
        python = pkgs.python312;
      in
      {
        devShells.default = pkgs.mkShell {
          name = "ornlkit";

          buildInputs = [
            # -- Python --
            python
            pkgs.uv

            # -- Rust --
            rustToolchain

            # -- General CLI tools --
            pkgs.just
            pkgs.jq
            pkgs.yq-go
            pkgs.ripgrep
            pkgs.fd
            pkgs.bat
            pkgs.gum
            pkgs.git

            # -- Container tooling (for building images locally) --
            pkgs.apptainer
          ];

          shellHook = ''
            echo "ornlkit dev shell"
            echo "  python : $(python3 --version)"
            echo "  uv     : $(uv --version)"
            echo "  cargo  : $(cargo --version)"
            echo ""
            # Return to the user's shell (nix develop forces bash)
            _user_shell=$(grep "^$USER:" /etc/passwd | cut -d: -f7) || true
            [ -x "''${_user_shell:-}" ] && [ "''${_user_shell##*/}" != bash ] && exec "$_user_shell"
          '';

          # Ensure UV doesn't fight with Nix's Python
          env = {
            UV_PYTHON_PREFERENCE = "only-system";
          };
        };

        # A minimal container image for Frontier, built with Nix.
        # Build with: nix build .#frontier-image
        # Then convert: apptainer build frontier.sif docker-archive://result
        packages.frontier-image = pkgs.dockerTools.buildLayeredImage {
          name = "ornlkit-frontier";
          tag = "latest";

          contents = [
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gawk
            python
            pkgs.uv
            rustToolchain
            pkgs.jq
            pkgs.ripgrep
            pkgs.fd
            pkgs.cacert
          ];

          config = {
            Env = [
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "UV_PYTHON_PREFERENCE=only-system"
            ];
            Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
          };
        };
      }
    );
}
