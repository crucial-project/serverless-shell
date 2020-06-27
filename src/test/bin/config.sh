#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJ_DIR=${DIR}/../../..
BIN_DIR=${PROJ_DIR}/src/main/bin
TMP_DIR=/tmp
DEBUG=1

sshell(){
    if [[ "$DEBUG" == "1" ]];
    then
	${BIN_DIR}/sshell.sh $@
    else
	${BIN_DIR}/sshell.sh $@ 2> /dev/null
    fi
}

export BIN_DIR
export DEBUG
export -f sshell
