#!/usr/bin/env bash

awslambdabugtrack()
{

  echo USAGE: AWS Lambda bug tracker arg1:FILE - arg2:Expected latency - arg3:Size of input file - arg4:Number of parallel jobs	
  echo 1st arg: $1
  echo 2nd arg: $2
  echo 3rd arg: $3
  echo 4th arg: $4

  cat $1 | grep Rate > awslambdabugreport.out

  cat awslambdabugreport.out

}

awslambdabugtrack $1 $2 $3 $4
