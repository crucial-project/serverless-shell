#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

success(){
  echo "ALL PASSED"
  exit 0
}

fail(){
  echo "FAILURE" $1
  exit 1
}

[[ ! -z $(sshell ls utils.sh | grep "utils.sh") ]] || fail 1
[[ ! -z $(sshellf ${DIR}/scripts/simple.sh | grep "utils.sh") ]] || fail 2
[[ ! -z $(sshell --async ls utils.sh | wc -c | grep 0) ]] || fail 3
[[ ! -z $(sshellf --async ${DIR}/scripts/simple.sh | wc -c | grep 0) ]] || fail 4

echo "ALL PASSED"
