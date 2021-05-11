#!/bin/bash

mvn clean install -DskipTests
cd src/main/bin
bash native.sh
bash layer -create
