#!/usr/bin/env bash

DIR=$(dirname "${BASH_SOURCE[0]}")
PROJDIR=${DIR}/../../../
TARGETDIR=${PROJDIR}/target

CLASSPATH=${CLASSPATH}:${TARGETDIR}/classes:${TARGETDIR}/lib/*

java org.crucial.shell.SShell $@
