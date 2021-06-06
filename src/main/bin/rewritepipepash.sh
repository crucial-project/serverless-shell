#!/usr/bin/env bash

PAR=8
input=($@)
#root=$(config "aws.efs.root")
root="/mnt/efsimttsp"

output="#!/usr/bin/env bash"
NEWLINE='\n'
output="${output} ${NEWLINE}"
output="${output} ${NEWLINE}"
output="${output} ${NEWLINE}"

patternskip1="rm_pash_fifos"
patternskip2="mkfifo_pash_fifos()"
patternskip3="rm -f"
patternskip4="mkfifo"
patternskip5="/pash/runtime/eager.sh"
patternskip6="/pash/runtime/auto-split.sh"
patternskip7="source"
patternskip8="&"
patternskip9=";"

pattern1="cat"

sendcmd="| awk '{print \\\$0}END{print \\\"EOF\\\"}' > "
recvcmd1="\"tail -n +0 --pid=\\$\\$ -f --retry"
recvcmd2="2>/dev/null | { sed \\\"/EOF/ q\\\" && kill \\$\\$ ;} | grep -v ^EOF\\$ |"

keyCmds=()
keyCmdStore=""
rm -f keyCmds.out
touch keyCmds.out

sshell="sshell"
flagCmd=0
dumpline=""
nblinesfile=""
cknblinesfile=""

while read line
do
        if echo "$line" | grep -q "$patternskip1" || echo "$line" | grep -q "$patternskip3" || echo "$line" | grep -q "$patternskip4" || echo $line | grep -q "$patternskip5" || echo $line | grep -q "$patternskip6" || echo $line | grep -q "$patternskip7" || echo $line | grep -q "$patternskip9"; then
      	#echo HIT
      		continue
        fi	

	line=$(echo $line | sed 's/{//g')
    	line=$(echo $line | sed 's/}//g')
    	#line=$(echo $line | sed 's/&//g')
    	line=$(echo $line | sed 's/;//g')
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
			#output="${output} ${tmparrayline}"
			#echo dumpline: $dumpline
		done

	#output+=${sshell}" \"${output}"\"
        continue
	fi

    	for index in "${!arrayline[@]}"
    	do
		flagCmd=1
		#echo index arrayline: $index
		if [ $index == 0 ]
		then
			echo index arrayline 0
			echo arrayline: ${arrayline[$index]}
			itercmd=0
			cmd=""
			while [[ ${arrayline[$itercmd]} != "<" && ${arrayline[$itercmd]} != *"/tmp"* ]]
			do
				cmd="$cmd ${arrayline[$itercmd]}"
				itercmd=$((itercmd+1))
				echo itercmd: $itercmd
			done
			#cmd="${arrayline[index]} "
			#cmd+="${arrayline[index+1]}"
			echo cmd: $cmd
			echo $cmd >> keyCmds.out
			keyCmdStore+="${arrayline[index]} "
			keyCmdStore+="${arrayline[index+1]}"
			keyCmdStore+=" "
			#echo cmd: $cmd
			#keyCmds+=($cmd)
			#keyCmds+=("${arrayline[index]} ${arrayline[index+1]}")
		fi

		if [[ "${arrayline[index]}" == *"tmp"* ]] ; then
	     	   #echo fifo substring: ${arrayline[index]}
			tmparrayline=${root}"/"$(uuid)
			#arrayline[index]=$tmparrayline
			#tmparrayline=${arrayline[index]}
        		#output="${output} ${tmparrayline}"
		#else
        		#output="${output} ${arrayline[index]}"
		fi
	done

	#echo flagCmd: $flagCmd
	#if [ $flagCmd == 1 ]
	#then
        	#output+=" ;"
		#output+="\n"
	#fi

	#for iter1 in $(seq 1 $PAR)
	#do
		#echo iter: $iter1
	#done
        #echo line: $line 
	#output+=${sshell}" \"${output}"\"
        #echo output: $output
	output+=$dumpline

done < $input

for k in ${keyCmds[@]}
do
	echo key Cmd: ${k}
done

echo keyCmdStore: $keyCmdStore
echo keyCmds file:
cat keyCmds.out
echo keyCmds file uniq:
cat keyCmds.out | uniq > keyCmdsUniq.out
echo keyCmdsUniq.out : 
cat keyCmdsUniq.out
itercmd=0
inputCmds=keyCmdsUniq.out
arrayCmds=""

while read -r linecmd
do
	itercmd=$((itercmd+1))
	echo iter key: $itercmd
	echo lineKey: $linecmd

	arrayCmds[$itercmd]=$linecmd
	#keyCmds[$iterKeys]=$linekey						
done < keyCmdsUniq.out

#echo keyCmds:
#for k in ${keyCmds[@]}
#do
#	echo key Cmd: ${k}
#done

nbstages=$(cat keyCmdsUniq.out | wc -l)
nbstagesmone=$((nbstages - 1))
echo Number of stages in pipeline: $nbstages

for itercmd in $(seq 1 $nbstages)
do
	echo arrayCmds $itercmd: ${arrayCmds[$itercmd]}
	if [ $itercmd == $nbstages ]
	then	
		fileparoutput=""
		for iterpar in $(seq 1 $PAR)
		do
			cmd=${arrayCmds[$itercmd]}
			output="${output} ${sshell} \"tail -n +0 --pid=\\$\\$ -f --retry "${pipe}" 2>/dev/null | { sed \\\"/EOF/ q\\\" && kill \\$\\$ ;} | grep -v ^EOF\\$ > ${root}/par_$iterpar.out\""
			output="${output} ${NEWLINE}"
			fileparoutput+=" ${root}/par_$iterpar.out"
		done

                output="${output} ${sshell} \"sort -m ${fileparoutput} > ${root}/res.out\""
		output="${output} ${NEWLINE}"

	elif [ $itercmd == $nbstagesmone ] 
	then
		for iterpar in $(seq 1 $PAR)
		do
			cmd=${arrayCmds[$itercmd]}
			output="${output} ${sshell} \"$cmd | awk '{print \\\$0}END{print \\\"EOF\\\"}' > "${pipe}"\"" 
			output="${output} ${NEWLINE}"
		done
	else
		cmd1=${arrayCmds[$itercmd]}
		cmd2=${arrayCmds[$itercmd+1]}

		for iterpar in $(seq 1 $PAR)
		do
			pipe="${root}/$(uuid)"
			outputsend="${sshell} \"$cmd1 | awk '{print \\\$0}END{print \\\"EOF\\\"}' > "${pipe}"\"" 
         		#outputsend+=${sshell}	
			outputrecv="${sshell} \"tail -n +0 --pid=\\$\\$ -f --retry "${pipe}" 2>/dev/null | { sed \\\"/EOF/ q\\\" && kill \\$\\$ ;} | grep -v ^EOF\\$ | $cmd2"
			#outputrecv+=${sshell}
			#echo $outputsend
			#echo $outputrecv
               		output="${output} $outputsend"
			output="${output} ${NEWLINE}"
			output="${output} $outputrecv"
			output="${output} ${NEWLINE}"

		done
	fi
done

#echo key Cmds: ${keyCmds}
echo OUTPUT
echo ==================
echo -e $output
