#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

EFSIODIR=$HOME/efs/benchio
EFSIOLAMBDADIR=/mnt/efsimttsp/benchio/files
NBRUNS=10

cleanup()
{
  rm -f *.out
}

runefsiobenchdownloadref()
{
  echo Calculate transfer rate of downloading a 1GB file
  sizefile=1000

  clock1=`date +%s` 
  echo start download 
  sshell "clock3=`date +%s` ; cp /mnt/efsimttsp/benchio/files/file1g.txt /dev/null ; clock4=`date +%s` ; durationdownload=\$(expr \$clock4 - \$clock3) ; echo \$durationdownload seconds" 
  clock2=`date +%s`
  echo download done 
  durationread=`expr $clock2 - $clock1` 
  echo duration reference read : $durationread seconds	

  transferrate=$((sizefile / $durationread))
  echo tranfer rate: $transferrate MB/s
}

# I/O operations on AWS EFS directory - DOWNLOAD
runefsiobenchdownload()
{
  
  echo Run EFS IO benchmark - DOWNLOAD : File size - $1 == Length input file - $2 == Number of parallel jobs - $3
  
  SIZEINPUTFILE=$2
  NBJOBS=$3
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
    head -n $SIZEINPUTFILE efsio.out | parallel -j$NBJOBS -I,, --env sshell "sshell \" clock5=\\\$(date +%s%N) ; cp $EFSIOLAMBDADIR/,, /dev/null ; clock6=\\\$(date +%s%N)  ; durationefsdownloadefs=\\\$(expr \\\$clock6 - \\\$clock5) \""
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
  
  echo Run EFS IO benchmark - UPLOAD : File size - $1 == Length input file - $2 == Number of parallel jobs - $3
  SIZEINPUTFILE=$2
  NBJOBS=$3
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
    head -n $SIZEINPUTFILE | parallel -j$NBJOBS -I,, --env sshell "sshell \" cp $EFSIOLAMBDADIR/,, /tmp ; clock7=\\\$(date +%s%N) ; cp /tmp/,, $EFSIOLAMBDADIR/write ; clock8=\\\$(date +%s%N) ; cd /tmp ; rm *.png ;cd .. ; durationuploadefs=\\\$(expr \\\$clock8 - \\\$clock7) \""
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
sizeinputfile=(100 200 300 400 500 600 700 800)

echo LAUNCH EFS I/O - DOWNLOAD

cleanup

runefsiobenchdownloadref

for strsizeelt in "${strSizeArrayDownload[@]}"
do
   for iinputfile in "${sizeinputfile[@]}"
   do
     for ijob in "${njobs[@]}"
     do 
       #echo size: $strsizeelt - length input file : $iinputfile - nb jobs: $ijob
       #sleep 3
       #runefsiobenchdownload $strsizeelt $iinputfile $ijob  > runefsiobenchdownload.$iinputfile-sizeinputfile.$ijob-nbparjobs.$strsizeelt-size.out
       #bash examples/perfbreakdown.sh runefsiobenchdownload.$iinputfile-sizeinputfile.$ijob-nbparjobs.$strsizeelt-size.out $strsizeelt $ijob $NBRUNS > benchefsio.perbreakdown.download.report.sizeinputfile-$iinputfile.nbparjobs-$ijob.filesize-$strsizeelt.out
       #bash examples/perfbreakdown.sh runefsiobenchdownload.$iinputfile-sizeinputfile.$ijob-nbparjobs.$strsizeelt-size.out $strsizeelt $ijob $NBRUNS > benchefsio.perbreakdown.download.report.sizeinputfile-$iinputfile.nbparjobs-$ijob.filesize-$strsizeelt.out
     done
   done
done

echo LAUNCH EFS I/O - UPLOAD

for strsizeelt in "${strSizeArrayUpload[@]}"
do
   for iinputfile in "${sizeinputfile[@]}"
   do
     for ijob in "${njobs[@]}"
     do 
       #echo size: $strsizeelt - length input file : $iinputfile - nb jobs: $ijob
       #sleep 3
       #runefsiobenchupload $strsizeelt $iinputfile $ijob  &> runefsiobenchupload.$iinputfile-sizeinputfile.$ijob-nbparjobs.$strsizeelt-size.out
       #bash examples/perfbreakdown.sh runefsiobenchupload.$iinputfile-sizeinputfile.$ijob-nbparjobs.$strsizeelt-size.out $strsizeelt $ijob $NBRUNS > benchefsio.perbreakdown.upload.report.sizeinputfile-$iinputfile.nbparjobs-$ijob.filesize-$strsizeelt.out
     done  
   done
done


#runefsiobench 10k 10
#runefsiobench 100k 10
#runefsiobench 1m 10
#runefsiobench 10m 10 
#runefsiobench 100m 10
