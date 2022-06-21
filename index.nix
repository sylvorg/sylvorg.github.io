with builtins; with (import (fetchGit {
    url = "https://github.com/shadowrylander/shadowrylander";
    ref = "main";
})).legacyPackages.${currentSystem} mkShell {
    buildInputs = [ PythonPackages.bakery yadm git gnumake fd emacs gnupg git-crypt tailscale tailapi pass ];
}
