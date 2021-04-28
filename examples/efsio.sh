#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

EFSIODIR=$HOME/efs/benchio/2g
EFSIOLAMBDADIR=/mnt/efsimttsp/benchio/2g
NBRUNS=10
SIZEFILE=2000 # 2 GB

cleanup()
{
  rm -f *.out
}

testsshelltimeout()
{

echo SSHELL sleep 60 seconds
sshell "sleep 60"
echo SSHELL sleep 120 seconds
sshell "sleep 120"
echo SSHELL sleep 300 seconds
sshell "sleep 300"
echo SSHELL sleep 600 seconds
sshell "sleep 600"

}

testparallelsshell()
{
  echo Test Parallel Lambda
  
  #NBJOBS=$1
  ls $EFSIODIR > efsio.out 
  
  echo Number of lines of output :
  sleep 2
  #cat efsio.out 
  cat efsio.out | wc -l > nbfilesefsbench.out
  cat nbfilesefsbench.out

  durationavgread=0 

  sleep 3

  # Read from AWS EFS directory
  for iter in $(seq 1 $NBRUNS)
  do
    echo iter: $iter
    sleep 4
    cat efsio.out | parallel -j10 -I,, --env sshell "sshell \" echo ,,  \""
  done

}

runefsiobenchdownloadref()
{
  echo Reference - Calculate transfer rate of downloading a 10GB file
  #sizefile=1000

  echo start no op operation
  clock1=`date +%s` 
  sshell "clock3=\$(date +%s) ; clock4=\$(date +%s) ; durationnoop=\$(expr \$clock4 - \$clock3) ; echo duration noop: \$durationnoop seconds" 
  clock2=`date +%s`
  echo download done 
  durationnoop=`expr $clock2 - $clock1` 
  echo duration reference noop : $durationnoop seconds	

  echo start download 
  clock5=`date +%s` 
  sshell "echo sshell - download a 2GB file ; clock7=\$(date +%s) ; cp /mnt/efsimttsp/benchio/2g/file1.2g.txt /dev/null ; clock8=\$(date +%s) ; echo finished download; durationdownload=\$(expr \$clock8 - \$clock7) ; echo duration download: \$durationdownload seconds " 
  clock6=`date +%s`
  echo download done 
  durationread=`expr $clock6 - $clock5` 
  echo duration reference read : $durationread seconds	

  transferrate=$(($SIZEFILE / $durationread))
  echo tranfer rate: $transferrate MB/s
}

# I/O operations on AWS EFS directory - DOWNLOAD
runefsiobenchdownload()
{
  
  #echo Run EFS IO benchmark - DOWNLOAD : File size - $1 == Length input file - $2 == Number of parallel jobs - $3
  echo Run EFS IO benchmark - DOWNLOAD : File size - $SIZEFILE - Number of parallel jobs - $1
  
  #NBJOBS=$1
  ls $EFSIODIR > efsio.out 
  
  echo Number of lines of output :
  sleep 2
  #cat efsio.out 
  cat efsio.out | wc -l > nbfilesefsbench.out
  cat nbfilesefsbench.out

  durationavgread=0 

  echo DOWNLOAD FROM AWS EFS
  sleep 3

  # Read from AWS EFS directory
  for iter in $(seq 1 $NBRUNS)
  do
    echo iter: $iter
    #sleep 2
    clock9=`date +%s`
    cat efsio.out | parallel -j10 -I,, --env sshell "sshell \" echo ,, ; clock11=\\\$(date +%s) ; cp $EFSIOLAMBDADIR/,, /dev/null ; clock12=\\\$(date +%s)  ; durationdownloadefs=\\\$(expr \\\$clock12 - \\\$clock11) ; echo duration download efs = \\\$durationdownloadefs seconds \""
    #cat efsio.out | parallel -j10 -I,, --env sshell "sshell \" echo ,, ; clock11=\\\$(date +%s) ; clock12=\\\$(date +%s)  ; durationdownloadefs=\\\$(expr \\\$clock12 - \\\$clock11) ; echo duration download efs = \\\$durationdownloadefs seconds \""
    clock10=`date +%s`
    durationread=`expr $clock10 - $clock9`
    durationavgread=$((durationavgread+$durationread))
  done

  durationavgread=$((durationavgread / ${NBRUNS}))

  echo Average duration DOWNLOAD : $durationavgread seconds 

  transferrate=$(($SIZEFILE / $durationavgread))
  echo tranfer rate: $transferrate MB/s

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

#njobs=(10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800)
njobs=(10 20 30 40 60 80 100 200 300 400 500 600 700 800)
sizeinputfile=(100 200 300 400 500 600 700 800)

echo LAUNCH EFS I/O - DOWNLOAD

cleanup

testsshelltimeout
#runefsiobenchdownloadref
#testparallelsshell

for ijob in "${njobs[@]}"
do
   echo ===============================
   echo nb jobs: $ijob
   runefsiobenchdownload $ijob
done

for strsizeelt in "${strSizeArrayDownload[@]}"
do
   for iinputfile in "${sizeinputfile[@]}"
   do
     for ijob in "${njobs[@]}"
     do 
       #echo size: $strsizeelt - length input file : $iinputfile - nb jobs: $ijob
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
