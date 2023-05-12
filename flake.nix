{
  description = "Demo environment for my Open Source Summit NA 2023 talk titled 'Automate Secret Rotation in Kubernetes, Then Get Out of the Way!'";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        versions = pkgs.writeScriptBin "versions" ''
          kind --version
          kubectl version --short --client
          echo kustomize $(kustomize version --short)
          echo helm $(helm version --short)
          vault --version
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [ versions ] ++ (with pkgs; [
            versions

            git
            gnumake

            kind
            kube3d
            kubectl
            kubectl-images
            kustomize
            kubernetes-helm

            vault
          ]);

          shellHook = ''
            versions
          '';
        };
      }
    );
}
