#! /usr/bin/env nix-shell
#[69509b6b-2e23-4c82-bbe3-0ec2a7dd916e[
#! nix-shell -p python310 python310Packages.bakery yadm git gnumake fd emacs gnupg2 pinentry git-crypt
#! nix-shell -I nixpkgs=https://github.com/shadowrylander/nixpkgs/archive/j.tar.gz
#! nix-shell -i hy
]69509b6b-2e23-4c82-bbe3-0ec2a7dd916e]
(import sys [argv])
(del (get argv 0))

(import bakery)
(import bakery [chown echo gpg git make nixos-generate-config yadm zfs])
(import click)
(import os [path listdir chmod getlogin expanduser symlink])
(import pathlib [Path])
(import stat)
(import socket)

(defn yes? [ var ] (in (.lower var) (, "y" "yes")))
(defn no? [ var ] (if (in (.lower var) (, "n" "no")) False var))
(defn iyes? [ query ] (yes? (input query)))
(defn repo-exists [ yadm-repo ]
      (and (.exists Path yadm-repo)
           (iyes? "Repo already exists! Force clone?"))))
(defn chmod-bootstrap [ bootstrap ] (.chmod bootstrap (| (| (| (.stat bootstrap) (.S_IEXEC stat)) (.S_IXGRP stat)) (.S_IXOTH stat))))
#@((.command click)
   (.option click "-b" "--bootstrap" :prompt True)
   (.option click "-i" "--impermanent" :prompt True)
   (.option click "-I" "--initialize-submodules" :prompt True)
   (.option click "-Y" "--import-yubikey" :prompt True)
   (.option click "-y" "--yadm-clone" :prompt True)
   (.option click "-z" "--zfs-root" :prompt True)
   (.option click "-p" "--primary-user" :prompt True)
   (.option click "-u" "--user-repo" :prompt True)
   (defn main [ impermanent import-yubikey git-clone yadm-clone secrets bootstrap zfs-root initialize-submodules primary-user user-repo ]
         (let [ current-user (getlogin)
                home (.home Path)
                username "shadowrylander"
                primary-user (if (yes? primary-user) username (if (iyes? "Is the current user the primary user?") current-user primary-user))
                primary-home (expanduser f"~{primary-user}")
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
                submodule-opts { "m/starter-args" (, "update")
                                 "m/exports" { "GIT_DISCOVERY_ACROSS_FILESYSTEM" 1 }
                                 "init" True
                                 "recursive" True
                                 "remote" True
                                 "force" True }
                bootstrap-path (Path f"{home}/.config/yadm/bootstrap")
                bootstrap-bin (bakery :program- bootstrap-path)
                reponame "aiern"
                user-repo (if (yes? user-repo) f"{home}/{reponame}" user-repo)
                primary-repo f"{primary-home}/{reponame}"
                yadm-repo f"{home}/.local/share/yadm/repo.git"
                dataset f"{(.gethostname socket)}/{primary-user}" ]
              (if import-yubikey
                  (do (gpg :fetch True)
                      (gpg :card-status True)
                      (| (echo (+ (.join "" (.split (get (gpg :fingerprint True "jeet.ray@syvl.org" :m/list True) 1))) ":6:")) (gpg :import-ownertrust))))
              (if (not (or (.exists path user-repo) (len (listdir user-repo))))
                  (do (if (not (or zfs-root (iyes? "Are you using a shared dataset for your central repo, such as `bcachefs' or `btrfs'?")))
                          (do (.mkdir (Path primary-repo) :parents True :exist-ok True)
                              (if (not (and (= current-user primary-user) (.exists path user-repo)))
                                  (symlink primary-repo user-repo))))
                      (.clone git f"https://github.com/{username}/{username}.git" user-repo)
                      (.remote (git :C user-repo) :m/starter-args (, "set-url") :push True "origin" f"git@github.com:{username}/{username}.git")

                      ;; If I unlock before I update the submodules, I can use `ssh://' urls immediately
                      (.crypt (git :C user-repo) "unlock")
                      (.submodule (git :C user-repo) #** submodule-opts)

                      (chown :R True f"{primary-user}:{primary-user}" user-repo)))
              (if yadm-clone
                  (do (.clone yadm :f (repo-exists home) #** clone-opts user-repo)
                      (.remote (git :C user-repo) :m/starter-args (, "add") current-user yadm-repo)
                      (.crypt yadm unlock)
                      (.submodule yadm #** submodule-opts)))
              (nixos-generate-config :run True)
              (if initialize-submodules
                  (do (if impermanent
                          (.gitconfig yadm "core.worktree" worktree))
                      (.submodule (yadm :C worktree) #** submodule-opts)
                      (.gitconfig yadm "core.worktree" home)
                      (make :f f"{worktree}/.emacs.d/makefile" "soft-init")))
              (if bootstrap
                  (do (chmod-bootstrap bootstrap-path)
                      (bootstrap-bin worktree)))
              (if zfs-root
                  (do (.set zfs :snapdir "visible" dataset :m/run True)
                      (.inherit zfs :r True "snapdir" dataset :m/run True))))))
