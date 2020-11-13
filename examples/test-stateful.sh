#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

success(){
  echo "ALL PASSED"
  exit 0
}

fail(){
  echo "FAILURE"
  exit 1
}


THREADS=4

[[ ! -z $(sshell "counter -n test reset; counter -n test increment -1 1" | grep "1") ]] || fail
[[ ! -z $(sshell "counter -n test increment -1 1" ) ]] || fail
[[ ! -z $(for i in $(seq 1 1 ${THREADS}); do sshell "counter -n test increment -1 1" & done; wait | tail -n 1 | grep $((THREADS+2))) ]] || fail
[[ ! -z $(BARRIER=$(uuid); for i in $(seq 1 1 ${THREADS}); do sshell barrier -n ${BARRIER} -p ${THREADS} await & done | grep ${THREADS}) ]] || fail

success
