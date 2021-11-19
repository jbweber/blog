#!/bin/bash

set -eo pipefail

printf "\033[0;32mdeploying updates...\033[0m\n"

git submodule update --init --recursive

pushd public
git checkout master
popd

hugo

pushd public
git add .
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"
git push origin master
popd
