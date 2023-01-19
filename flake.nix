{
  description = "Demo environment for my FOSDEM23 talk titled 'Automating secret rotation in Kubernetes'";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      rec
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            kind
            kubectl
            kubernetes-helm
          ];

          shellHook = ''
            ${pkgs.kind}/bin/kind --version
            ${pkgs.kubectl}/bin/kubectl version --client
            echo helm $(${pkgs.kubernetes-helm}/bin/helm version --short)
          '';
        };
      });
}
