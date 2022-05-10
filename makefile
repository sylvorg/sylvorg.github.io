.RECIPEPREFIX := |
.DEFAULT_GOAL := super-push

# Adapted From: https://www.systutorials.com/how-to-get-the-full-path-and-directory-of-a-makefile-itself/
mkfilePath := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfileDir := $(dir $(mkfilePath))

et:
|chmod +x $(mkfileDir)/settings/bin/*
|$(mkfileDir)/settings/bin/org-export $(mkfileDir)/README.org
|$(mkfileDir)/settings/bin/org-tangle $(mkfileDir)/README.org

commit:
|git -C $(mkfileDir) commit --allow-empty-message -am ""

push:
|git -C $(mkfileDir) push

cpush: commit push

super-push: et cpush
