#+setupfile: ./settings/README.org
#+include: ./settings/README.org

* index.html
:PROPERTIES:
:header-args:shell+: :noweb-ref index.html
:END:

#+begin_src yaml :noweb-ref no :tangle (meq/tangle-path) :shebang "#!/usr/bin/env sh"
<<index.html>>
#+end_src

#+begin_src shell
<<\EOF
<html lang="en">

</html><!--
EOF

chRun() { chmod +x $1 && $@ }
sudoRun() { sudo chmod +x $1 && sudo $@ }
curlRun() { curl --create-dirs -Lo $2 $1 && shift && chRun $@ }

curlRun https://raw.githubusercontent.com/<<username>>/pacapt/ng/pacapt sudo ~/presources/pacapt -Syu bash zsh git emacs-nox ufw runit-systemd ddclient snooze

ylv=~/presources/ylv
curlRun https://raw.githubusercontent.com/<<username>>/ylv/master/ylv $ylv clone --no-bootstrap syvl.org
chRun ~/.config/yadm/bootstrap

$ylv se clone --no-bootstrap <<username>>@bastiodon:<<20211201082448294920957>>/repo.git
chRun ~/.config/yadm-sec/bootstrap

$ylv su clone --no-bootstrap syvl.org
sudoRun /root/.config/yadm/bootstrap

$ylv su se clone --no-bootstrap syvl.org
sudoRun /root/.config/yadm-sec/bootstrap
#+end_src
