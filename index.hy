#! /usr/bin/env nix-shell
"
#! nix-shell -p python310 python310Packages.bakery yadm git gnumake fd emacs gnupg2 pinentry transcrypt
#! nix-shell -I nixpkgs=https://github.com/shadowrylander/nixpkgs/archive/j.tar.gz
#! nix-shell -i hy
"
(import sys [argv])
(del (get argv 0))

(import bakery)
(import bakery [echo gpg make nixos-generate-config yadm zfs])
(import click)
(import os [path] [chmod])
(import pathlib [Path])
(import stat)
(import socket)

(defn yes? [ var ] (in (.lower var) (, "y" "yes")))
(defn no? [ var ] (if (in (.lower var) (, "n" "no")) False var))
(defn repo-exists []
      (and (.exists Path (.join path home ".local" "share" "yadm" "repo.git"))
           (yes? (input "Repo already exists! Force clone?"))))
(defn chmod-bootstrap [ bootstrap ] (.chmod bootstrap (| (| (| (.stat bootstrap) (.S_IEXEC stat)) (.S_IXGRP stat)) (.S_IXOTH stat))))
#@((.command click)
   (.option click "-b" "--bootstrap" :prompt True)
   (.option click "-i" "--impermanent" :prompt True)
   (.option click "-I" "--initialize-submodules" :prompt True)
   (.option click "-Y" "--import-yubikey" :prompt True)
   (.option click "-y" "--yadm-clone" :prompt True)
   (.option click "-z" "--zfs-root" :prompt True)
   (defn main [ impermanent import-yubikey yadm-clone secrets bootstrap zfs-root initialize-submodules ]
         (let [ home (.home Path)
                impermanent (yes? impermanent)
                worktree (if impermanent
                            f"/persist/{home}"
                            home)
                yadm-clone (yes? yadm-clone)
                zfs-root (yes? zfs-root)
                import-yubikey (yes? import-yubikey)
                initialize-submodules (yes? initialize-submodules)
                bootstrap (yes? bootstrap)
                clone-opts { "w" worktree "no-bootstrap" True }
                bootstrap-path (Path f"{home}/.config/yadm/bootstrap")
                bootstrap-bin (bakery :program- bootstrap-path)
                dataset f"{(.gethostname socket)}/shadowrylander" ]
              (if import-yubikey
                  (do (gpg :fetch True)
                      (gpg :card-status True)
                      (| (echo (+ (.join "" (.split (get (gpg :fingerprint True "jeet.ray@syvl.org" :m/list True) 1))) ":6:")) (gpg :import-ownertrust))))
              (if yadm-clone
                  (do (.clone yadm :f (repo-exists) #** clone-opts "https://github.com/shadowrylander/shadowrylander.git")
                      (.remote yadm :m/starter-args (, "set-url") :push True "origin" "git@github.com:shadowrylander/shadowrylander.git")
                      (.crypt yadm unlock)))
              (nixos-generate-config :run True)
              (if initialize-submodules
                  (do (if impermanent
                          (.gitconfig yadm "core.worktree" worktree))
                      (.submodule (yadm :C worktree) :m/starter-args (, "update") :m/exports { "GIT_SSL_NO_VERIFY" 1 "GIT_DISCOVERY_ACROSS_FILESYSTEM" 1 } :init True :recursive True :remote True :force True)
                      (.gitconfig yadm "core.worktree" home)
                      (make :f f"{worktree}/.emacs.d/makefile" "soft-init")))
              (if bootstrap
                  (do (chmod-bootstrap bootstrap-path)
                      (bootstrap-bin worktree)))
              (if zfs-root
                  (do (.set zfs :snapdir "visible" dataset :m/run True)
                      (.inherit zfs :r True "snapdir" dataset :m/run True))))))
