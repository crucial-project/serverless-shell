#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CONFIG_DIR=${DIR}
LIB_DIR=${DIR}/../../../target/lib
SRC_DIR=${DIR}/../../../target/
PROJ_DIR=${DIR}/../../..

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
AWS_S3_BUCKET=$(config aws.s3.bucket)
AWS_S3_KEY=$(config aws.s3.key)

if [[ "$1" == "-create" ]]
then
    mvn package -DskipTests -f ${PROJ_DIR}
    rm -Rf ${ZIP_DIR}
    mkdir -p ${ZIP_DIR} ${ZIP_DIR}/bin ${ZIP_DIR}/java/lib ${ZIP_DIR}/var/task
    # dependencies
    cp -Rf ${LIB_DIR}/*.jar ${ZIP_DIR}/java/lib
    # binaries
    cp -Rf ${DIR}/tools/* ${ZIP_DIR}/bin
    # build, deploy
    cd ${ZIP_DIR} && zip -qr code.zip * && cd ${DIR}
    aws s3api put-object --bucket ${AWS_S3_BUCKET} --key ${AWS_S3_KEY} --body ${ZIP_DIR}/code.zip > /dev/null
    version=$(aws --profile=default --region us-east-1 lambda publish-layer-version \
        --layer-name serverless-bash \
        --description serverless-bash \
        --license-info "Apache" \
        --content S3Bucket=${AWS_S3_BUCKET},S3Key=${AWS_S3_KEY} \
        --compatible-runtimes java11 | grep "\"Version\":" | awk -F: '{print $2}' | sed s/[\ ,]//g)
    # FIXME
    aws lambda add-layer-version-permission \
    	--layer-name serverless-bash \
    	--statement-id rights \
    	--version-number ${version} \
    	--principal '*' \
    	--action lambda:GetLayerVersion \
    	--output text \
    	--region=${AWS_REGION}
elif [[ "$1" == "-delete" ]]
then
    echo "NYI"
    exit 0
elif [[ "$1" == "-exists" ]]
then
	echo "NYI"
	exit 0
else
    usage
fi
