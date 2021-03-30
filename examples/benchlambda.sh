#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

EFSIODIR=$HOME/efs/benchio
EFSIOLAMBDADIR=/mnt/efsimttsp/benchio
NBRUNS=4

cleanup()
{
  rm -f *.out
}

# I/O operations on AWS EFS directory - DOWNLOAD
runlambda()
{
  
  echo Run LAMBDA BENCHMARK : Length input file - $1 == sleep latency = $2 == Number of parallel jobs - $3
  
  SIZEINPUTFILE=$1
  NLATENCY=$2
  NBJOBS=$3
  #ls $EFSIODIR | grep $1 > efsio.out 
  ls $EFSIODIR > efsio.out 
  
  echo Number of lines of output :
  sleep 2
  cat efsio.out 
  cat efsio.out | wc -l > nbfilesefsbench.out
  cat nbfilesefsbench.out

  sleep 2
  durationavgread=0 

  echo LAMBDA SLEEP TEST
  sleep 3

  # Sleep test
  for iter in $(seq 1 $NBRUNS)
  do
    echo iter: $iter
    clock1=`date +%s`
    head -n $SIZEINPUTFILE efsio.out | parallel -j$NBJOBS -I,, --env sshell "sshell \" clock5=\\\$(date +%s%N) ; echo ,, > /dev/null ; usleep $NLATENCY ; clock6=\\\$(date +%s%N)  ; durationlatency=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationlatency = \\\$durationlatency \""
    clock2=`date +%s`
    durationsleep=`expr $clock2 - $clock1`
    durationavgsleep=$((durationavgsleep+$durationsleep))
  done

  durationavgsleep=$((durationavgsleep / ${NBRUNS}))

  echo Average duration SLEEP : $durationavgsleep seconds 

}

njobs=(10 20 30 40 60 80 100 200 300 400 500 600 700 800)
sizeinputfile=(100 200 300 400 500 600 700 800 1000 2000 3000 4000)
nlatency=(10000 20000 40000 60000 80000 100000 200000 400000 600000 800000 1000000)
#nlatency=(80000 100000 200000 400000 600000 800000 1000000)

cleanup

for iinputfile in "${sizeinputfile[@]}"
do
  for ilatency in "${nlatency[@]}"
  do
    for ijob in "${njobs[@]}"
    do
      if [ "$ijob" -lt "$iinputfile" ]
      then
        echo length input file : $iinputfile - latency : $ilatency us - nb jobs: $ijob
        sleep 3
        runlambda $iinputfile $ilatency $ijob &> runlambdalatency.latency-$ilatency.nbparjobs-$ijob.inputfile-$iinputfile.out
        bash examples/perfbreakdown.sh runlambdalatency.latency-$ilatency.nbparjobs-$ijob.inputfile-$iinputfile.out $ilatency $iinputfile $NBRUNS 
        bash examples/bugtracker.sh runlambdalatency.latency-$ilatency.nbparjobs-$ijob.inputfile-$iinputfile.out $ilatency $iinputfile $ijob
      fi
    done
  done
done

