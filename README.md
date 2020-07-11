# Serverless shell

The serverless shell brings the powerfulness of shell scripting to the serverless world.
It is particularly convenient to mine large public data sets available on the internet.
A typical use case is to download a data sample on the local machine, write the code logic using this sample then execute the same code massively in parallel in a serverless infrastructure.
Currently, only AWS Lambda is supported as a backend.
Work is in progress to include other serverless services (e.g., knative).

## For the impatient

	git clone https://github.com/crucial-project/serverless-shell
	mvn install -DskipTests -f serverless-shell # the DSO and executor must have been installed previously
	export ACCOUNT=%MY_AWS_ACCOUNT%
	export ROLE_NAME=%AWS_IAM_ROLE_NAME% # the role must have access to AWS Lambda
	cat serverless-shell/src/main/bin/config.properties.tmpl | sed s/ACCOUNT/${ACCOUNT}/g | sed s/ROLE_NAME/${ROLE_NAME}/g > serverless-shell/src/main/bin/config.properties
	serverless-shell/src/main/bin/deploy.sh -create # upload the function image to AWS Lambda 
	serverless-shell/src/main/bin/sshell.sh ls

## Installation

The serverless shell requires to install previously the [DSO](https://github.com/crucial-project/dso) and [executor](https://github.com/crucial-project/executor) components of the Crucial project.
Once this is done, clone the serverless shell directory and install it using `mvn install -DskipTests`.

The serverless shell requires a working AWS client.
If this is not the case, please follow the instructions available [online](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

To run the serverless shell, we first upload an image in AWS Lambda.
The parameters with which the image is uploaded are defined in `serverless-shell/src/main/bin/config.properties`.
A template is available in the repository under the name `serverless-shell/src/main/bin/config.properties.tmpl`.
Copy the template then rename it appropriately after having changed the placeholders `ACCOUNT` and `ROLE_NAME` with respectively your AWS account and AWS IAM role.
The AWS IAM role should have the rights to access AWS Lambda.
Uploading the serverless shell image to Lambda is done by executing `serverless-shell/src/main/bin/deploy.sh -create`.

## Usage

The syntax of the serverless shell is quite straightforward.
Use the `sshell.sh` program located under `serverless-shell/src/main/bin` followed by the shell command(s) to execute.
For instance, `serverless-shell/src/main/bin/sshell.sh ls` lists the content of the container executing the serverless shell.

## Examples

Several examples are provided under `src/test/bin/commoncrawl.sh`.
These examples cover the use of the [Common Crawl](https://commoncrawl.org)  data set.
For instance, the `average` function in `src/test/bin/commoncrawl.sh` evaluates the average web page size over a chunk of this data set.

## Stateful computation

Serverless shell invocations may access shared objects through the DSO layer.
To access this feature, it is necessary first to launch one (or more) DSO servers following the installation [guide](https://github.com/crucial-project/dso).
Once this is done, indicate the entry point of the DSO layer in `config.properties` using variable `crucial.server` (whose default value is `IP:PORT`).

The syntax to access a data type is of the form `type -n name [operation]`, where `type` is the data type and `name` its storage key in the DSO layer.
For instance, `counter -n my_counter -i 1` increment by 1 the counter named `my_counter`.
The data types currently available are listed under `serverless-shell/src/main/bin/aliases.sh.tmpl`

