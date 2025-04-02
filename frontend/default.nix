{
  stdenv,
  nodejs,
  nix-filter, # an instance of https://github.com/numtide/nix-filter
  cacert,
  elm,
  uglify-js,
  elm-test,
}:

# https://zimbatm.com/notes/nix-packaging-the-heretic-way
let
  # Get version from package.json
  version = (builtins.fromJSON (builtins.readFile ./package.json)).version;

  self = {

    # Build the node_modules separately, from package.json and package-lock.json.
    #
    # Use __noChroot = true trick to avoid having to re-compute the vendorSha256 every time.
    node_modules = stdenv.mkDerivation {
      name = "node_modules";

      src = nix-filter {
        root = ./.;
        include = [
          ./package.json
          ./package-lock.json
        ];
      };

      # HACK: break the nix sandbox so we can fetch the dependencies. This
      # requires Nix to have `sandbox = relaxed` in its config.
      __noChroot = true;

      configurePhase = ''
        # NPM writes cache directories etc to $HOME.
        export HOME=$TMP

        # Set SSL certificates for npm
        export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
        export NODE_EXTRA_CA_CERTS=${cacert}/etc/ssl/certs/ca-bundle.crt
      '';

      buildInputs = [ nodejs ];

      # Pull all the dependencies
      buildPhase = ''
        ${nodejs}/bin/npm ci --no-audit --no-progress
      '';

      # NOTE[z]: The folder *must* be called "node_modules". Don't ask me why.
      #          That's why the content is not directly added to $out.
      installPhase = ''
        mkdir $out
        mv node_modules $out/node_modules
      '';

      timeout = 60;
    };

    frontend = stdenv.mkDerivation {
      pname = "receptdatabasen-frontend";
      inherit version;

      src = nix-filter {
        root = ./.;
        exclude = [
          ./node_modules
        ];
      };

      nativeBuildInputs = [
        nodejs
        elm
        uglify-js
      ];

      configurePhase = ''
        # Get the node_modules from its own derivation
        ln -sf ${self.node_modules}/node_modules node_modules
        export HOME=$TMP
      '';

      # HACK: elm make will need internet access
      __noChroot = true;

      buildPhase = ''
        ${nodejs}/bin/npm run build
      '';

      checkInputs = [
        nodejs
        elm
        elm-test
      ];

      doCheck = true;
      checkPhase = ''
        ${nodejs}/bin/npm run test
      '';

      installPhase = ''
        mkdir -p $out
        cp -r dist/* $out/
      '';
    };

  };
in
self
