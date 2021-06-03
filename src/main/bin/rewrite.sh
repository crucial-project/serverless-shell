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

PAR=2
chunks=()

# AWS EFS
root=$(config "aws.efs.root")
pipes=()
patternskip1="rm_pash_fifos"
patternskip2="mkfifo_pash_fifos()"
patternskip3="rm -f"
patternskip4="mkfifo"
patternskip5="/pash/runtime/eager.sh"
patternskip6="/pash/runtime/auto-split.sh"
patternskip7="source"
patternskip8="&"

pattern1="cat"

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
    if echo "$line" | grep -q "$patternskip1" || echo "$line" | grep -q "$patternskip3" || echo "$line" | grep -q "$patternskip4" || echo $line | grep -q "$patternskip5" || echo $line | grep -q "$patternskip6" || echo $line | grep -q "$patternskip7"; then
      	#echo HIT
      	continue
    fi
    #if [[ "$line" == *"fifo"* ]] ; then 
    #	echo FIFO
    #fi

    line=$(echo $line | sed 's/{//g')
    line=$(echo $line | sed 's/}//g')
    line=$(echo $line | sed 's/&//g')
    line=$(echo $line | sed 's/</< /g')
    line=$(echo $line | sed 's/>/> /g')

    #echo line: $line 
    dumpline=""
    nblinesfile=""
    cknblinesfile=""

    if echo "$line" | grep -q "$pattern1"
    then
	nblinesfile=$(cat ${arrayline[index+1]} | wc -l)
	#echo Number of lines of input file: $nblinesfile
	cknblinesfile=$(($nblinesfile/$PAR))
        echo "line got cat"
    	for iter in $(seq 0 $PAR)
    	do
    		echo iter: $iter
		if [ $iter -eq $zero ]; then
    			tmparrayline="head -n $cknblinesfile ${arrayline[index+1]} > ${root}/$(uuid) ;" 
    			dumpline="${dumpline} ${tmparrayline}"	
    			echo dumpline: $dumpline
		else
			tmparrayline="tail -n $cknblinesfile ${arrayline[index+1]} > ${root}/$(uuid) ;" 
    			dumpline="${dumpline} ${tmparrayline}"
			echo iter tail: $iter	
    			echo dumpline: $dumpline

		fi
    	done
    else

    IFS=', ' read -r -a arrayline <<< "$line"
    for index in "${!arrayline[@]}"
    do
	#echo elem: ${arrayline[index]}
        if echo ${arrayline[index]} | grep -q "$pattern1"; then
		nblinesfile=$(cat ${arrayline[index+1]} | wc -l)
		#echo Number of lines of input file: $nblinesfile
		cknblinesfile=$(($nblinesfile/$PAR))
		#remainnblines=$(($nblinesfiles - $cknblinesfile*PAR))
		for iter1 in $(seq 1 10)
		do
			echo iter: $iter1
			#uuid=$(uuidgen)
			if [ "$iter1" == 1 ]; then
				tmparrayline="head -n $cknblinesfile ${arrayline[index+1]} > ${root}/$(uuid) ;" 
			else
				tmparrayline="tail -n $cknblinesfile ${arrayline[index+1]} > ${root}/$(uuid) ;" 
			fi
		 	dumpline="${dumpline} ${tmparrayline}"	
			echo dumpline: $dumpline
		done
		break
		#echo Number of lines of each chunk: $cknblinesfile
        elif [[ "${arrayline[index]}" == *"tmp"* ]] ; then 
	        #echo fifo substring: ${arrayline[index]}
		tmparrayline=${root}"/"$(uuid)
		#arrayline[index]=$tmparrayline
		#tmparrayline=${arrayline[index]}
        	dumpline="${dumpline} ${tmparrayline}"
	else
        	dumpline="${dumpline} ${arrayline[index]}"
	fi
    done
    fi
    echo dumpline: $dumpline
    #echo After line replacement : ${line//tmp*/fs}
    #echo match pattern: $matchpattern
    #if [ -n "$matchpattern4" ]; then
    #  echo HIT
    #  continue
    #fi
    #echo ------------------
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
