#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[[ ! -z "${LIB_DIR}" ]] || LIB_DIR=${DIR}
[[ ! -z "${SRC_DIR}" ]] || SRC_DIR=${DIR}
[[ ! -z "${CONFIG_DIR}" ]] || CONFIG_DIR=${DIR}
TMP_DIR=/tmp/$(whoami)
ZIP_DIR=${TMP_DIR}/code

CONFIG_FILE=${CONFIG_DIR}/config.properties

if [ ! -f ${CONFIG_FILE} ];
then
    >&2 echo "${CONFIG_FILE} is missing."
fi

config() {
    if [ $# -ne 1 ]; then
        echo "usage: config key"
        exit -1
    fi
    local key=$1
    cat ${CONFIG_FILE} | grep -E "^${key}=" | cut -d= -f2
}

sshell(){
	sshell.bin -c $@
}

sshellf(){
	sshell.bin -f $@
}

export PATH=${PATH}:${DIR}
export -f sshell
export -f sshellf
