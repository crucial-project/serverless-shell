#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

EFSIODIR=$HOME/efs/benchio
EFSIOLAMBDADIR=/mnt/efsimttsp/benchio
NBRUNS=10

cleanup()
{
  rm -f *.out
}

# I/O operations on AWS EFS directory - DOWNLOAD
runefsiobenchdownload()
{
  
  echo Run EFS IO benchmark - DOWNLOAD : File size - $1  - Number of parallel jobs - $2
  NBJOBS=$2
  ls $EFSIODIR | grep $1 > efsio.out 
  
  echo Number of lines of output :
  sleep 2
  cat efsio.out 
  cat efsio.out | wc -l > nbfilesefsbench.out
  cat nbfilesefsbench.out

  sleep 2
  durationavgread=0 

  echo DOWNLOAD FROM AWS EFS
  sleep 3

  # Read from AWS EFS directory
  for iter in $(seq 1 $NBRUNS)
  do
    echo iter: $iter
    clock1=`date +%s`
    head -n 100 efsio.out | parallel -j$NBJOBS -I,, --env sshell "sshell \" clock5=\\\$(date +%s%N) ; cp $EFSIOLAMBDADIR/,, /tmp ; clock6=\\\$(date +%s%N)  ; durationefsdownloadefs=\\\$(expr \\\$clock6 - \\\$clock5) ; cd /tmp ; rm *.png ; cd .. \""
    clock2=`date +%s`
    durationread=`expr $clock2 - $clock1`
    durationavgread=$((durationavgread+$durationread))
  done

  durationavgread=$((durationavgread / ${NBRUNS}))

  echo Average duration DOWNLOAD : $durationavgread seconds 

}

# I/O operations on AWS EFS directory - UPLOAD
runefsiobenchupload()
{
  
  echo Run EFS IO benchmark - UPLOAD : File size - $1  - Number of parallel jobs - $2
  NBJOBS=$2
  ls $EFSIODIR | grep $1 > efsio.out 
  
  echo Number of lines of output :
  sleep 2
  cat efsio.out 
  cat efsio.out | wc -l > nbfilesefsbench.out
  cat nbfilesefsbench.out

  sleep 2
  durationavgwrite=0 

  echo UPLOAD TO AWS EFS
  sleep 3
  # Write to AWS EFS directory
  for iter in $(seq 1 $NBRUNS)
  do
    echo iter : $iter
    rm -rf $EFSIODIR/write/*
    clock3=`date +%s`
    cat efsio.out | parallel -j$NBJOBS -I,, --env sshell "sshell \" cp $EFSIOLAMBDADIR/,, /tmp ; clock7=\\\$(date +%s%N) ; cp /tmp/,, $EFSIOLAMBDADIR/write ; clock8=\\\$(date +%s%N) ; cd /tmp ; rm *.png ;cd .. ; durationuploadefs=\\\$(expr \\\$clock8 - \\\$clock7) \""
    clock4=`date +%s`
    durationwrite=`expr $clock4 - $clock3`
    durationavgwrite=$(($durationavgwrite+$durationwrite))
  done

  durationavgwrite=$((durationavgwrite / ${NBRUNS}))

  echo Average duration WRITE : $durationavgwrite seconds

}

echo RUN BENCH EFS I/O - Read / Write 

declare -a strSizeArray=("10k" "100k" "1m" "10m" "100m")
declare -a strSizeArrayDownload=("1m" "10m" "100m")
declare -a strSizeArrayUpload=("10k" "100k")

njobs=(10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800)

echo LAUNCH EFS I/O - DOWNLOAD

cleanup

for strsizeelt in "${strSizeArrayDownload[@]}"
do

   for ijob in "${njobs[@]}"
   do 
     echo size: $strsizeelt - nb jobs: $ijob
     sleep 3
     runefsiobenchdownload $strsizeelt $ijob  > runefsiobenchdownload.$ijob-nbparjobs.$strsizeelt-size.out
     bash examples/perfbreakdown.sh runefsiobenchdownload.$ijob-nbparjobs.$strsizeelt-size.out $strsizeelt $ijob $NBRUNS > benchefsio.perbreakdown.download.report.nbparjobs-$ijob.filesize-$strsizeelt.out
   done
done

echo LAUNCH EFS I/O - UPLOAD

for strsizeelt in "${strSizeArrayUpload[@]}"
do

   for ijob in "${njobs[@]}"
   do 
     echo size: $strsizeelt - nb jobs: $ijob
     sleep 3
     runefsiobenchupload $strsizeelt $ijob  > runefsiobenchupload.$ijob-nbparjobs.$strsizeelt-size.out
     bash examples/perfbreakdown.sh runefsiobenchupload.$ijob-nbparjobs.$strsizeelt-size.out $strsizeelt $ijob $NBRUNS > benchefsio.perbreakdown.upload.report.nbparjobs-$ijob.filesize-$strsizeelt.out
   done
done


#runefsiobench 10k 10
#runefsiobench 100k 10
#runefsiobench 1m 10
#runefsiobench 10m 10 
#runefsiobench 100m 10
