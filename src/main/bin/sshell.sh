#!/usr/bin/env bash

DIR=$(dirname "${BASH_SOURCE[0]}")
PROJDIR=${DIR}/../../../
TARGETDIR=${PROJDIR}/target

export CLASSPATH=${CLASSPATH}:${TARGETDIR}/*:${TARGETDIR}/lib/*

java -Xmx32m org.crucial.shell.SShell $@
