#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJ_DIR=${DIR}/../../..
TARGET_DIR=${PROJ_DIR}/target
TMP_DIR=/tmp/$(whoami)
CONFIG_FILE=${DIR}/config.properties

config() {
    if [ $# -ne 1 ]; then
        echo "usage: config key"
        exit -1
    fi
    local key=$1
    cat ${CONFIG_FILE} | grep -E "^${key}=" | cut -d= -f2
}

usage(){
    echo "usage: -[create|delete]"
    exit -1
}

SERVER=$(config crucial.server)

if [ $# -ne 1 ];
then
    usage
fi

AWS_REGION=$(config aws.region)
AWS_ROLE=$(config aws.iam.role)
AWS_S3_BUCKET=$(config aws.s3.bucket)
AWS_S3_KEY=$(config aws.s3.key)
AWS_LAMBDA_FUNCTION_NAME=$(config aws.lambda.function.name)
AWS_LAMBDA_FUNCTION_HANDLER=$(config aws.lambda.function.handler)

if [[ "$1" == "-create" ]]
then    
    mvn clean package -DskipTests -f ${PROJ_DIR}
    AWS_CODE="S3Bucket=${AWS_S3_BUCKET},S3Key=${AWS_S3_KEY}"
    APP_JAR="$(config app)-$(config version).jar"
    APP_TEST_JAR="$(config app)-$(config version)-tests.jar"
    CODE_DIR=${TMP_DIR}/code
    rm -Rf ${CODE_DIR}
    mkdir -p ${CODE_DIR}
    rm -f ${TMP_DIR}/code.zip
    mkdir -p ${CODE_DIR}/lib
    cp -Rf ${TARGET_DIR}/lib ${CODE_DIR}
    cp -Rf ${TARGET_DIR}/classes/* ${CODE_DIR}/
    # cp -Rf ${TARGET_DIR}/test-classes/* ${CODE_DIR}/
    sed s/%SERVER%/${SERVER}/g ${CODE_DIR}/aliases.sh.tmpl > ${CODE_DIR}/aliases.sh
    cd ${TMP_DIR}/code && zip -r code.zip * && mv code.zip .. && cd ${PROJ_DIR} # FIXME
    # aws s3 cp ${TMP_DIR}/code.zip s3://${AWS_S3_BUCKET}/${AWS_S3_KEY}
    aws lambda create-function \
	--region=${AWS_REGION} \
    	--function-name ${AWS_LAMBDA_FUNCTION_NAME} \
    	--runtime java8 \
    	--timeout 60 \
    	--memory-size 2048 \
    	--role ${AWS_ROLE} \
    	--handler ${AWS_LAMBDA_FUNCTION_HANDLER} \
    	--zip-file fileb://${TMP_DIR}/code.zip  > ${TMP_DIR}/log.dat
    cat ${CONFIG_FILE}
    # echo "aws.lambda.function.arn=$(grep FunctionArn ${TMP_DIR}/log.dat  | awk -F": " '{print $2}' | sed s,[\"\,],,g)"
elif [[ "$1" == "-delete" ]]
then
    aws lambda delete-function \
	--region=${AWS_REGION} \
	--function-name ${AWS_LAMBDA_FUNCTION_NAME}	
else
    usage
fi
