with builtins; with (fetchGit {
    url = "https://github.com/shadowrylander/shadowrylander";
    ref = "";
}).legacyPackages.${currentSystem}; mkShell {
    buildInputs = [ pythonPackages.bakery yadm git gnumake fd emacs gnupg git-crypt tailscale tailapi pass ];
}
