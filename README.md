# Serverless shell

The serverless shell brings the power of shell scripting to the serverless world.
It is particularly convenient to mine large public data sets available on the internet.
A typical use case is to download a data sample on the local machine, write the code logic using this sample then execute the same code massively in parallel in a serverless infrastructure.

Currently, only AWS Lambda is supported as a servrless backend.
Work is in progress to include other services (e.g., knative).

## Installation

    wget https://github.com/crucial-project/serverless-shell/releases/download/2.0/serverless-shell-2.0-bin.tar.gz 
    tar zxvf serverless-shell-2.0-bin.tar.gz
	export ACCOUNT=%AWS_ACCOUNT_ID%
	export ROLE_NAME=%AWS_IAM_ROLE_NAME% # the role must have access to AWS Lambda
	cat serverless-shell-2.0/config.properties.tmpl | sed s,ACCOUNT,${ACCOUNT},g | sed s,ROLE_NAME,${ROLE_NAME},g > config.properties
	export CONFIG_DIR=.; sed -i s,FUNCTION_ARN,$(./serverless-shell-2.0/deploy.sh -create | grep FunctionArn | awk '{print $2}' | sed s,[\"\,],,g),g config.properties
	source ./serverless-shell-2.0/utils.sh
 	sshell ls # check that everything works

## Demo

[![asciicast](https://asciinema.org/a/dCoEaE4UXHDUu4XUlf1DqcQQj.svg)](https://asciinema.org/a/dCoEaE4UXHDUu4XUlf1DqcQQj)

## Usage

The syntax of the serverless shell is straightforward.
Use `sshell` followed by the command(s) to execute.
It is also possible to pass a script file with `sshellf`.

## Examples

Several examples are provided in the `examples` directory.
In particular, some unit tests can be run under `examples/test.sh`.
More involved examples are available in `examples/commoncrawl.sh`.
These examples cover the use of the [Common Crawl](https://commoncrawl.org) data set.
For instance, the `average` function in `commoncrawl.sh` evaluates the average web page size over a chunk of this data set.

## Stateful computation

Side effects when executing `sshell` are possible using a shared objects layer.
To access this feature, it is necessary to launch one (or more) DSO servers, as explained in the installation [guide](https://github.com/crucial-project/dso).
Once this is done, indicate the entry point of the DSO layer in `config.properties` with variable `crucial.server` (whose default value is `IP:PORT`).
Then, re-install the serverless shell (`deploy.sh -delete; deploy.sh -create`).
To check that everything works fine, you may run `examples/tests-stateful.sh`.

The syntax to access a data type is of the form `type -n name operation`, where `type` is the data type and `name` its storage key in the DSO layer.
For instance, `counter -n my_counter -1 1` increment by 1 the counter named `my_counter`.
The data types currently available are listed under `serverless-shell/src/main/bin/aliases.sh`.  
