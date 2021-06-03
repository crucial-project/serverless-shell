#!/usr/bin/env bash

PAR=2
input=($@)
root=$(config "aws.efs.root")

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
flagCmd=0
dumpline=""
output=""
nblinesfile=""
cknblinesfile=""

while read line
do
        if echo "$line" | grep -q "$patternskip1" || echo "$line" | grep -q "$patternskip3" || echo "$line" | grep -q "$patternskip4" || echo $line | grep -q "$patternskip5" || echo $line | grep -q "$patternskip6" || echo $line | grep -q "$patternskip7"; then
      	#echo HIT
      		continue
        fi	

	line=$(echo $line | sed 's/{//g')
    	line=$(echo $line | sed 's/}//g')
    	line=$(echo $line | sed 's/&//g')
    	line=$(echo $line | sed 's/</< /g')
    	line=$(echo $line | sed 's/>/> /g')

	IFS=', ' read -r -a arrayline <<< "$line"

	if echo $line | grep -q "$pattern1"
	then
		flagCmd=1
		nblinesfile=$(cat ${arrayline[index+1]} | wc -l)
		cknblinesfile=$((nblinesfile / $PAR))

		for iter in $(seq 1 $PAR) 
		do
			#echo iter2: $iter
			if [ "$iter" == 1 ]; then
				#echo head
				tmparrayline="head -n $cknblinesfile ${arrayline[index+1]} > ${root}/$(uuid) ;" 
			else
				#echo tail
				tmparrayline="tail -n $cknblinesfile ${arrayline[index+1]} > ${root}/$(uuid) ;" 
			fi
			output="${output} ${tmparrayline}"
			#echo dumpline: $dumpline
		done

	#output+=${sshell}" \"${output}"\"
        continue
	fi

    	for index in "${!arrayline[@]}"
    	do
		flagCmd=1
		if [[ "${arrayline[index]}" == *"tmp"* ]] ; then
	     	   #echo fifo substring: ${arrayline[index]}
			tmparrayline=${root}"/"$(uuid)
			#arrayline[index]=$tmparrayline
			#tmparrayline=${arrayline[index]}
        		output="${output} ${tmparrayline}"
		else
        		output="${output} ${arrayline[index]}"
		fi
	done

	echo flagCmd: $flagCmd
	if [ $flagCmd == 1 ]
	then
        	output+=" ;"
	fi

	#for iter1 in $(seq 1 $PAR)
	#do
		#echo iter: $iter1
	#done
        #echo line: $line 
	#output+=${sshell}" \"${output}"\"
        #echo output: $output
	output+=$dumpline

done < $input


echo OUTPUT
echo ==================
echo $output
