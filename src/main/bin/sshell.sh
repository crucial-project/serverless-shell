#!/usr/bin/env bash

DIR=$(dirname "${BASH_SOURCE[0]}")
PROJDIR=${DIR}/../../../
TARGETDIR=${PROJDIR}/target

CLASSPATH=${CLASSPATH}:${TARGETDIR}/*:${TARGETDIR}/lib/*

java -Xshare:on eu.cloudbutton.shell.SShell $@
