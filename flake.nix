{
    description = "The flake for sylvorg.github.io!";
    inputs.bootstrap.url = github:sylvorg/bootstrap;
    outputs = inputs@{ self, bootstrap, ... }: bootstrap // { pname = "sylvorg.github.io"; };
}
