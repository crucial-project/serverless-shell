#!/usr/bin/env bash

PAR=2

input=($@)
#root=$(config "aws.efs.root")
root="/mnt/efsimttsp"
arrayPipes=""
arrayPipesNext=""

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
pattern2="head"

sendcmd="awk '{print \\\$0}END{print \\\"EOF\\\"}'"
#recvcmd="tail -n +0 --pid=\\$\\$ -f --retry"
recvcmd="cat"
#recvcmd2="2>/dev/null | { sed \\\"/EOF/ q\\\" && kill \\$\\$ ;} | grep -v ^EOF\\$"
#recvcmd2="2>/dev/null | { sed \\\"/EOF/ q\\\" && kill \\$\\$ ;} | grep -v ^EOF\\$"

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
		nblinesfile=$(cat ${arrayline[1]} | wc -l)
		echo $nblinesfile
		cknblinesfile=$((nblinesfile / $PAR))
		
		for iterpar in $(seq 1 $PAR) 
		do
			arrayPipes[$iterpar]="${root}/$(uuid)"
			#echo iter2: $iter
			if [ "$iterpar" == 1 ] 
			then
				#echo head
				output="${output} ${sshell} \"head -n $cknblinesfile ${root}${arrayline[1]} > ${arrayPipes[$iterpar]} \""
				output="${output} ${NEWLINE}"
			else
				offset=$(($iterpar * $cknblinesfile))
				#echo tail
				output="${output} ${sshell} \"head -n $offset ${root}${arrayline[1]} | tail -n +${cknblinesfile} > ${arrayPipes[$iterpar]} \"" 
				output="${output} ${NEWLINE}"
			fi
		done
        	continue

	elif echo $line | grep -q "$pattern2"
	then
		nblinesfile=${arrayline[2]}
		cknblinesfile=$((nblinesfile / $PAR))

		for iterpar in $(seq 1 $PAR) 
		do
			arrayPipes[$iterpar]="${root}/$(uuid)"
			#echo iter2: $iter
			if [ "$iterpar" == 1 ] 
			then
				#echo head
				output="${output} ${sshell} \"head -n $cknblinesfile ${root}/${arrayline[3]} > ${arrayPipes[$iterpar]} \""
				output="${output} ${NEWLINE}"
			else
				offset=$(($iterpar * $cknblinesfile))
				#echo tail
				output="${output} ${sshell} \"head -n $offset ${root}/${arrayline[3]} | tail -n +${cknblinesfile} > ${arrayPipes[$iterpar]} \"" 
				output="${output} ${NEWLINE}"
			fi
		done
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
			echo cmd: $cmd
			echo $cmd >> keyCmds.out
			keyCmdStore+="${arrayline[index]} "
			keyCmdStore+="${arrayline[index+1]}"
			keyCmdStore+=" "
		fi

	done

done < $input

for k in ${keyCmds[@]}
do
	echo key Cmd: ${k}
done

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
	linecmd=$(echo $linecmd | sed "s/\"/'/g")
	echo iter key: $itercmd

	echo lineKey: $linecmd

	arrayCmds[$itercmd]=$linecmd
	#keyCmds[$iterKeys]=$linekey						
done < keyCmdsUniq.out

nbstages=$(cat keyCmdsUniq.out | wc -l)
nbstagesmone=$((nbstages - 1))
echo Number of stages in pipeline: $nbstages

output="${output} ${NEWLINE}"

for itercmd in $(seq 1 $nbstages)
do
	echo arrayCmds $itercmd: ${arrayCmds[$itercmd]}
	if [ $itercmd == $nbstages ]
	then	
		fileparoutput=""
		output="${output} ${NEWLINE}"
		output="${output} ${NEWLINE}"

		for iterpar in $(seq 1 $PAR)
		do
			cmd=${arrayCmds[$itercmd]}
			output="${output} ${sshell} \"${recvcmd} "${arrayPipes[$iterpar]}" > ${root}/par_$iterpar.out\""
			output="${output} ${NEWLINE}"
			fileparoutput+=" ${root}/par_$iterpar.out"
		done

		output="${output} ${NEWLINE}"
		output="${output} ${NEWLINE}"
                output="${output} ${sshell} \"sort -m ${fileparoutput} > ${root}/res.out\""
		output="${output} ${NEWLINE}"

	else
		cmd=${arrayCmds[$itercmd]}

		for iterpar in $(seq 1 $PAR)
		do
			arrayPipesNext[$iterpar]="${root}/$(uuid)"
			output="${output} ${sshell} \" ${recvcmd} ${arrayPipes[$iterpar]} | ${cmd} > ${arrayPipesNext[$iterpar]} \""
			output="${output} ${NEWLINE}"
			arrayPipes[$iterpar]=${arrayPipesNext[$iterpar]}

		done
		output="${output} ${NEWLINE}"
		output="${output} ${NEWLINE}"
	fi
done

echo OUTPUT
echo ==================
echo -e $output > pipessshellefs_${PAR}_chunks.sh 
