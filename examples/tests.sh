#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[[ ! -z $(sshell ls utils.sh | grep "utils.sh") ]] || exit 1
[[ ! -z $(sshellf ${DIR}/scripts/simple.sh | grep "utils.sh") ]] || exit 1
[[ ! -z $(sshell --async ls utils.sh | grep -v "utils.sh") ]] || exit 1
[[ ! -z $(sshellf --async ${DIR}/scripts/simple.sh | grep "utils.sh") ]] || exit 1


echo "ALL PASSED"
