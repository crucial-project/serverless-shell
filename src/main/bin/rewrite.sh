#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${DIR}/utils.sh

OLDIFS=$IFS
IFS="|"
input=($@)
if [[ ${#input[@]} -eq 1 ]];
then
    exit 0
fi

# AWS EFS
root=$(config "aws.efs.root")
pipes=()

sshell="sshell"
for i in ${input[@]};
do
    cmd=$(echo $i | sed 's/"/\\"/g')
    if [[ $start == "1" ]];
    then
    	# AWS EFS
    	pipe=${root}"/"$(uuid)
    	# pipe=${root}"/test"
    	output+=" | awk '{print \\\$0}END{print \\\"EOF\\\"}' > "${pipe}"\" &\n"
    	output+=${sshell}
    	if [[ ${cmd} != ${input[-1]} ]];
    	then
    	    output+="" # --async FIXME
    	fi
    	output+=" \"tail -n +0 --pid=\\$\\$ -f --retry "${pipe}" 2>/dev/null | { sed \\\"/EOF/ q\\\" && kill \\$\\$ ;} | grep -v ^EOF\\$ | "${cmd}
    	pipes+=(${pipe})
    else
    	start="1"
    	output+=${sshell}" \""${cmd} # --async 
    fi
done
output+="\""
for p in ${pipes[@]}
do
    output+="\n"${sshell}" \"rm -f "${p}"\" &"
done
output+="\nwait"
IFS=$OLDIFS
echo -e  ${output}
