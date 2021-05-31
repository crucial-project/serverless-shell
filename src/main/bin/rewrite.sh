#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${DIR}/utils.sh

OLDIFS=$IFS
IFS="|"
input=($@)
#if [[ ${#input[@]} -eq 1 ]];
#then
#    exit 0
#fi

# AWS EFS
root=$(config "aws.efs.root")
pipes=()
patternskip1="rm_pash_fifos"
patternskip2="mkfifo_pash_fifos()"
patternskip3="rm -f"
patternskip4="mkfifo"
patternskip5="/pash/runtime/eager.sh"
patternskip6="source"

sshell="sshell"
inputbash="$1"
echo input: $inputbash
echo =======================================
#for i in ${input[@]};
while read line
do
    #matchpattern=$(echo $line | grep -q "$pattern1" || echo $line | grep -q "$pattern2" || echo $line | grep -q "$pattern3")
    matchpattern4=$(echo $line | grep -q "$pattern4")
    matchpattern3=$(echo $line | grep -q "$pattern3")
    if echo "$line" | grep -q "$patternskip1" || echo "$line" | grep -q "$patternskip3" || echo "$line" | grep -q "$patternskip4" || echo $line | grep -q "$patternskip5" || echo $line | grep -q "$patternskip6"; then
      	#echo HIT
      	continue
    fi
    if [[ "$line" == *"fifo"* ]] ; then 
	echo FIFO
    fi

    #echo match pattern: $matchpattern
    #if [ -n "$matchpattern4" ]; then
    #  echo HIT
    #  continue
    #fi
    #echo ------------------
    line=$(echo $line | sed 's/</< /g')
    line=$(echo $line | sed 's/>/> /g')
    echo line: $line
    #cmd=$(echo $i | sed 's/"/\\"/g')
    cmd=$(echo $line | sed 's/"/\\"/g')
    #echo CMD: $cmd
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
done < $input
#done
output+="\""
for p in ${pipes[@]}
do
    output+="\n"${sshell}" \"rm -f "${p}"\" &"
done
output+="\nwait"
IFS=$OLDIFS
#echo -e  ${output}
