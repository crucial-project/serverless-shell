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

THREADS=4

[[ ! -z $(sshell "counter -n test reset; counter -n test increment -1 1" | grep "1") ]] || fail 1
[[ ! -z $(sshell "counter -n test increment -1 1" ) ]] || fail 2
[[ ! -z $(for i in $(seq 1 1 ${THREADS}); do sshell "counter -n test increment -1 1" & done; wait | tail -n 1 | grep $((THREADS+2))) ]] || fail 3
[[ ! -z $(BARRIER=$(uuid); for i in $(seq 1 1 ${THREADS}); do sshell barrier -n ${BARRIER} -p ${THREADS} await & done | grep ${THREADS}) ]] || fail 4
[[ ! -z $(MAP=$(uuid); sshell "map -n ${MAP} mergeAll -1 \"1=1\" -1 \"2=1\" -2 sum; for i in \$(map -n ${MAP} keySet); do echo \"\$i=\$(map -n ${MAP} get -1 \$i)\"; done" | grep "1=1") ]] || fail 5
[[ ! -z $(MAP=$(uuid); sshell "treemap -n ${MAP} mergeAll -1 \"1=1\" -1 \"2=1\" -2 sum; for i in \$(treemap -n ${MAP} keySet); do echo \"\$i=\$(treemap -n ${MAP} get -1 \$i)\"; done" | grep "1=1") ]] || fail 5

success
