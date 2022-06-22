#! /usr/bin/env nix-shell
#[69509b6b-2e23-4c82-bbe3-0ec2a7dd916e[
#! nix-shell shell
#! nix-shell -i hy
#! nix-shell --option tarball-ttl 0
]69509b6b-2e23-4c82-bbe3-0ec2a7dd916e]
(import bakery)
(import bakery [chown echo gpg git make nixos-generate-config systemctl tailapi tailscale uname yadm zfs])
(import click)
(import os [path listdir chmod getlogin symlink])
(import pathlib [Path])
(import stat)
(import socket)
(import uuid [uuid4 uuid5])

(defn yes? [ var ] (in (.lower var) (, "y" "yes")))
(defn dyes? [ var default ] (if (yes? var) default var))
(defn iyes? [ query ] (yes? (input query)))
(defn idyes? [ query default ] (dyes? (input query) default))
(defn no? [ var ] (if (in (.lower var) (, "n" "no")) False var))
(defn ino? [ query ] (no? (input query)))
(defn repo-exists [ yadm-repo ]
      (and (.exists path yadm-repo)
           (iyes? "Repo already exists! Force clone?")))
(defn chmod-bootstrap [ bootstrap ] (.chmod bootstrap (| (| (| (.stat bootstrap) (.S_IEXEC stat)) (.S_IXGRP stat)) (.S_IXOTH stat))))
#@((.command click)
   (.option click "-b" "--bootstrap" :prompt "Run yadm bootstrap")
   (.option click "-i" "--impermanent" :prompt "Root wiped on boot")
   (.option click "-I" "--initialize-yadm-submodules" :prompt True)
   (.option click "-I" "--initialize-primary-submodules" :prompt True)
   (.option click "-Y" "--import-yubikey" :prompt True)
   (.option click "-y" "--yadm-clone" :prompt True)
   (.option click "-z" "--zfs-root" :prompt "On a zfs root")
   (.option click "-p" "--primary-user" :prompt "You're the primary user (or enter another user here)")
   (.option click "-u" "--user-repo" :prompt "Use the default user repo (or enter another repo path here)")
   (.option click "-g" "--gpg-key-id" :prompt "Use the default gpg key id (or enter another id, such as the name, email address, etc. here)")
   (.option click "-t" "--tailscale-domain" :prompt "Use the default Tailscale domain (or enter another one here)")
   (.option click "-a" "--tailscale-api-key" :prompt "Use the default Tailscale api key (or enter another one here)" :hide-input True :confirmation-prompt True)
   (.option click "-A" "--tailscale-api-command" :prompt "Use the default Tailscale api command (or enter another one here)")
   (defn main [ bootstrap
                impermanent
                import-yubikey
                initialize-primary-submodules
                initialize-yadm-submodules
                primary-user
                tailscale-api-command
                tailscale-api-key
                tailscale-domain
                user-repo gpg-key-id
                yadm-clone
                zfs-root ]
         (let [ current-user (getlogin)
                home (.home Path)
                username "shadowrylander"
                primary-user (if (yes? primary-user) username (if (iyes? "Current user the primary user: ") current-user primary-user))
                primary-home (.expanduser path f"~{primary-user}")
                impermanent (yes? impermanent)
                worktree (if impermanent
                            f"/persist/{home}"
                            home)
                yadm-clone (yes? yadm-clone)
                zfs-root (yes? zfs-root)
                import-yubikey (yes? import-yubikey)
                initialize-yadm-submodules (yes? initialize-yadm-submodules)
                initialize-primary-submodules (yes? initialize-primary-submodules)
                bootstrap (yes? bootstrap)
                clone-opts { "w" worktree "no-bootstrap" True }
                submodule-opts { "m/starter-args" (, "update")
                                 "m/exports" { "GIT_DISCOVERY_ACROSS_FILESYSTEM" 1 }
                                 "init" True
                                 "recursive" True
                                 "remote" True
                                 "force" True }
                bootstrap-path (Path f"{home}/.config/yadm/bootstrap")
                reponame "aiern"
                user-repo (dyes? user-repo f"{home}/{reponame}")
                primary-repo f"{primary-home}/{reponame}"
                yadm-repo f"{home}/.local/share/yadm/repo.git"
                hostname (.gethostname socket)
                dataset f"{hostname}/{primary-user}"
                gpg-key-id (dyes? gpg-key-id "jeet.ray@syvl.org")
                tailscale-domain (dyes? tailscale-domain "sylvorg.github")
                tailscale-api-key (dyes? tailscale-api-key None)
                tailscale-api-command (dyes? tailscale-api-command "pass show keys/api/tailscale/jeet.ray")
                tailscale-api-command-split (.split tailscale-api-command)
                tailscale-api-command-bin (bakery (get tailscale-api-command-split 0))
                tailscale-api-command-args (cut tailscale-api-command-split 1 None) ]
              (if import-yubikey
                  (do (while True
                             (try (print "The gnupg card status:\n")
                                  (gpg :card-status True :m/dazzle True)
                                  (print)
                                  (except [e SystemError]
                                          (print f"Sorry; either your yubikey isn't inserted or something else happened! When all set up, please press enter; in the meantime, here is the error: {(repr e)}")
                                          (input))
                                  (else (break))))
                      (for [line (gpg :card-status True :m/split "\n")]
                           (if (in "URL" line)
                               (do (gpg :fetch (get (.split line ": ") 1))
                                   (break)))))
                  (if (setx gpg-key (ino? "Path to gpg private key: "))
                      (while True
                             (try (gpg :m/subcommand "import" gpg-key)
                                  (except [e SystemError]
                                          (print f"Sorry; either your key could not be imported or something else happened! When all set up, please press enter; in the meantime, here is the error: {(repr e)}")
                                          (input))
                                  (else (break))))
                      (raise (ValueError "Sorry; a gpg key is necessary to continue!"))))
              (while True
                     (try (| (echo (+ (.join "" (.split (get (gpg :fingerprint True gpg-key-id :m/list True) 1))) ":6:")) (gpg :import-ownertrust True))
                          (except [e SystemError]
                                  (print f"Sorry; either your key trust could not be imported or something else happened! When all set up, please press enter; in the meantime, here is the error: {(repr e)}")
                                  (input))
                          (else (break))))
              (if (not (or (.exists path user-repo) (len (listdir user-repo))))
                  (do (if (not (or zfs-root (iyes? "Currently using a shared dataset for your central repo, such as via `bcachefs' or `btrfs': ")))
                          (do (.mkdir (Path primary-repo) :parents True :exist-ok True)
                              (if (not (and (= current-user primary-user) (.exists path user-repo)))
                                  (symlink primary-repo user-repo))))
                      (.clone git f"https://github.com/{username}/{username}.git" user-repo)
                      (.remote (git :C user-repo) :m/starter-args (, "set-url") :push True "origin" f"git@github.com:{username}/{username}.git")

                      ;; If I unlock before I update the submodules, I can use `ssh://' urls immediately
                      (.crypt (git :C user-repo) "unlock")
                      (.submodule (git :C user-repo) :m/regular-args (, ".password-store") #** submodule-opts)

                      (if (!= (uname :o True :m/str True) "Android")
                          (if (.exists path "/var/lib/tailscale/tailscaled.state")
                              (if (not (or (in "tailscale0:" (ifconfig :m/split True))
                                           (in "tun0:" (ifconfig :m/split True))))
                                  (if impermanent
                                      (.up tailscale :hostname (uuid5 (uuid4) (str (uuid4)))
                                                     :authkey (.create (tailapi :domain tailscale-domain
                                                                                :recreate-response True
                                                                                :api-key (or tailscale-api-key
                                                                                             (tailscale-api-command-bin #* tailscale-api-command-args)))
                                                                                :ephemeral True
                                                                                :just-key True
                                                                                "bootstrap"))
                                      (.up tailscale :hostname hostname
                                                     :authkey (.create (tailapi :domain tailscale-domain
                                                                                :recreate-response True
                                                                                :api-key (or tailscale-api-key
                                                                                             (tailscale-api-command-bin #* tailscale-api-command-args)))
                                                                                :ephemeral (iyes? "Set the ephemeral property for this tailscale authkey: ")
                                                                                :preauthorized (iyes? "Set the pre-authorized property for this tailscale authkey: ")
                                                                                :reusable (iyes? "Set the reusable property for this tailscale authkey: ")
                                                                                :just-key True
                                                                                (input "Tags to set for this authkey, as a string of tags separated by spaces: ")))))
                              (raise (ValueError "Sorry; enable the tailscale daemon to continue!"))))

                      (if initialize-primary-submodules
                          (do (.submodule (git :C user-repo) #** submodule-opts)
                              (for [ m (.submodule yadm :m/starter-args (, "foreach") :recursive True :m/list True) ]
                                   (.crypt (git :C (+ user-repo "/" (get (.split m "'") 1))) "unlock" :m/ignore-stderr True))))
                      (chown :R True f"{primary-user}:{primary-user}" user-repo)))
              (if yadm-clone
                  (do (.clone yadm :f (repo-exists home) #** clone-opts user-repo)
                      (.remote (git :C user-repo) :m/starter-args (, "add") current-user yadm-repo)
                      (.crypt yadm unlock)
                      (if initialize-yadm-submodules
                          (do (if impermanent
                                  (.gitconfig yadm "core.worktree" worktree))
                              (.submodule yadm #** submodule-opts)
                              (for [ m (.submodule yadm :m/starter-args (, "foreach") :recursive True :m/list True) ]
                                   (.crypt (git :C (+ worktree "/" (get (.split m "'") 1))) "unlock" :m/ignore-stderr True))
                              (.gitconfig yadm "core.worktree" home)
                              (make :f f"{worktree}/.emacs.d/makefile" "soft-init")))))
              (nixos-generate-config :run True)
              (if bootstrap
                  (do (chmod-bootstrap bootstrap-path)
                      ((bakery :program- bootstrap-path) worktree)))
              (if zfs-root
                  (do (.set zfs :snapdir "visible" dataset :m/run True)
                      (.inherit zfs :r True "snapdir" dataset :m/run True))))))

(if (= __name__ "__main__") (main))
