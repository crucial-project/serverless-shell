#!/usr/bin/env bash

DIR=$(dirname "${BASH_SOURCE[0]}")

SRC_DIR=${DIR}/../../../target
LIB_DIR=${DIR}/../../../target/lib
CLASSPATH=${SRC_DIR}/*:${LIB_DIR}/*

java -Xmx32m org.crucial.shell.SShell $@
