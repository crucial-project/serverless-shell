package org.crucial.shell;

public class Config {
    public static final String CONFIG_FILE = "config.properties";

    public static final String AWS_LAMBDA_DEBUG = "debug";
    public static final String AWS_LAMBDA_DEBUG_DEFAULT = "false";

    public static final String AWS_LAMBDA_FUNCTION_ASYNC = "async";
    public static final String AWS_LAMBDA_FUNCTION_ASYNC_DEFAULT = "false";

    public static final String AWS_LAMBDA_REGION = "aws.region";
    public static final String AWS_LAMBDA_REGION_DEFAULT = "AWS_REGION";

    public static final String AWS_LAMBDA_FUNCTION_ARN = "aws.lambda.function.arn";
    public static final String AWS_LAMBDA_FUNCTION_ARN_DEFAULT = "arn:aws:lambda:AWS_REGION:ID:function:NAME";

}