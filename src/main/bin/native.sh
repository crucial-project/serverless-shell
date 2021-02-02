#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CONFIG_DIR=${DIR}
LIB_DIR=${DIR}/../../../target/lib
SRC_DIR=${DIR}/../../../target/
PROJ_DIR=${DIR}/../../..

GRAAL=19.3.0.r11-grl

pushd ${PROJ_DIR}
# sdk use java ${GRAAl}
mvn clean package -Dproject.skip-native-image=false
popd

