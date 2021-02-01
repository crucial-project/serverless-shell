#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${DIR}/utils.sh

usage(){
    echo "usage: -[create|delete|exists]"
    exit -1
}

SERVER=$(config crucial.server)

if [ $# -ne 1 ];
then
    usage
fi

AWS_REGION=$(config aws.region)
AWS_ROLE=$(config aws.iam.role)
AWS_LAMBDA_FUNCTION_NAME=$(config aws.lambda.function.name)
AWS_LAMBDA_FUNCTION_HANDLER=$(config aws.lambda.function.handler)

LAYER_VERSION=23

if [[ "$1" == "-create" ]]
then
    APP_JAR="$(config app)-$(config version).jar"
    rm -Rf ${ZIP_DIR}
    mkdir -p ${ZIP_DIR}
    # application
    APP_JAR="$(config app)-$(config version).jar"
    cp -Rf ${DIR}/{utils.sh,aliases.sh} ${ZIP_DIR}
    cp -f ${CONFIG_FILE} ${ZIP_DIR}
    cd ${ZIP_DIR} && jar xf ${SRC_DIR}/${APP_JAR} && cd ${DIR}
    # build, deploy
    cd ${ZIP_DIR} && zip -qr code.zip * && cd ${DIR}
    aws lambda create-function \
	--region=${AWS_REGION} \
    	--function-name ${AWS_LAMBDA_FUNCTION_NAME} \
    	--layers arn:aws:lambda:us-east-1:667743079194:layer:serverless-bash:${LAYER_VERSION} \
    	--runtime java11 \
    	--timeout 30 \
    	--memory-size 1024 \
    	--role ${AWS_ROLE} \
    	--handler ${AWS_LAMBDA_FUNCTION_HANDLER} \
    	--zip-file fileb://${ZIP_DIR}/code.zip
elif [[ "$1" == "-delete" ]]
then
    aws lambda delete-function \
	--region=${AWS_REGION} \
	--function-name ${AWS_LAMBDA_FUNCTION_NAME}
elif [[ "$1" == "-exists" ]]
then
	[[ ! -z "$(aws lambda list-functions --region=${AWS_REGION} | grep ${AWS_LAMBDA_FUNCTION_NAME})" ]] || exit 1
	exit 0
else
    usage
fi
