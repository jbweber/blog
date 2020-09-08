#!/bin/bash

set -eo pipefail

printf "\033[0;32mdeploying updates...\033[0m\n"

hugo
cd public
git add .
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"
git push origin master
