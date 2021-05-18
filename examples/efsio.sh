#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

EFSIOREAD10GDIR=$HOME/efs/benchio/read/10g
EFSIOLAMBDADIR=/mnt/efsimttsp/benchio/read/10g
EFSIOLAMBDADIRWRITE=/mnt/efsimttsp/benchio/write
EFSIOEC2DIRWRITE=/$HOME/efs/benchio/benchio/write
NBRUNS=1
SIZEFILE=100 # 100 MB
INPUTSIZE=1000

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
 
  echo Calculate ref transfer rate in download 
  durationaccreadref=0
  durationavgreadref=0

  for iter in $(seq 1 $NBRUNS) 
  do
    echo $iter
    clock5=`date +%s` 
    sshell "echo sshell - download a 10GB file ; clock7=\$(date +%s) ; cp /mnt/efsimttsp/benchio/read/10g/file1.10g.txt /dev/null ; clock8=\$(date +%s) ; echo finished download; durationdownload=\$(expr \$clock8 - \$clock7) ; echo duration download: \$durationdownload seconds " 
    clock6=`date +%s`
    durationreadref=`expr $clock6 - $clock5` 
    durationaccreadref=$((durationaccreadref+$durationreadref))
  done

  echo download done 
  durationavgreadref=$((durationaccreadref / ${NBRUNS}))
  echo Average duration reference read : $durationavgreadref seconds	

  transferrate=$(($SIZEFILE / $durationavgreadref))
  echo tranfer rate: $transferrate MB/s
}

runefsiobenchuploadref()
{
  echo Reference - Calculate transfer rate of uploading a 10GB file
  #sizefile=1000

  durationaccwriteref=0
  durationavgwriteref=0

  for iter in $(seq 1 $NBRUNS) 
  do
    echo $iter
    clock5=$(date +%s)
    sshell "dd if=/dev/zero of=$EFSIOLAMBDADIRWRITE/large-file-10gb-$iter.txt count=1024 bs=10485760" 
    clock6=$(date +%s)
    durationwriteref=$(expr $clock6 - $clock5)
    durationaccwriteref=$((durationaccwriteref+$durationwriteref))
  done

  echo upload done 
  durationavgwriteref=$((durationaccwriteref / ${NBRUNS}))
  echo Average duration reference write : $durationavgwriteref seconds	

  transferrate=$(($SIZEFILE / $durationavgwriteref))
  echo transfer rate: $transferrate MB/s
}


# I/O operations on AWS EFS directory - DOWNLOAD
runefsiobenchdownload()
{
  
  #echo Run EFS IO benchmark - DOWNLOAD : File size - $1 == Length input file - $2 == Number of parallel jobs - $3
  echo Run EFS IO benchmark - DOWNLOAD : File size - $SIZEFILE - Number of parallel jobs - $1
 
  echo Arg 1: $1 
  NBJOBS=$1
  ls $EFSIOREAD10GDIR > efsio.out 
  
  echo Number of lines of output :
  sleep 2
  #cat efsio.out 
  cat efsio.out | wc -l > nbfilesefsbench.out
  cat nbfilesefsbench.out
  headcat=$((2 * ${NBJOBS}))
  echo headcat: $headcat

  echo DOWNLOAD FROM AWS EFS
  sleep 1

  clock9=$(date +%s)
  # Read from AWS EFS directory
  for iter in $(seq 1 $NBRUNS)
  do
    echo iter: $iter
    head -n $INPUTSIZE efsio.out | parallel -j$NBJOBS -I,, --env sshell "sshell \" echo ,, ; clock11=\\\$(date +%s) ; cp $EFSIOLAMBDADIR/,, /dev/null ; clock12=\\\$(date +%s)  ; durationdownloadefs=\\\$(expr \\\$clock12 - \\\$clock11) \""
    #cat efsio.out | parallel -j10 -I,, --env sshell "sshell \" echo ,, ; clock11=\\\$(date +%s) ; clock12=\\\$(date +%s)  ; durationdownloadefs=\\\$(expr \\\$clock12 - \\\$clock11) ; echo duration download efs = \\\$durationdownloadefs seconds \""
  done
  clock10=$(date +%s)

  durationread=$(expr $clock10 - $clock9)
  echo duration DOWNLOAD : $durationread seconds 
 
  globaldatasize=$(($SIZEFILE * $INPUTSIZE))
  transferrate=$((globaldatasize / $durationread))
  echo tranfer rate: $transferrate MB/s

}

# I/O operations on AWS EFS directory - UPLOAD
runefsiobenchupload()
{
  
  echo Run EFS IO benchmark - UPLOAD :  Number of parallel jobs - $1
  echo Input size: ${INPUTSIZE}
  JOBS=$1
  
  clock3=$(date +%s)
  # Write to AWS EFS directory
  for iter in $(seq 1 $NBRUNS)
  do
    echo iter : $iter
    seq 1 1 ${INPUTSIZE} | parallel -j$JOBS -I,, --env sshell "sshell \"dd if=/dev/zero of=$EFSIOLAMBDADIRWRITE/large-file-100mb-\$iter-,,-\${PARALLEL_SEQ}.txt count=1024 bs=102400 status=none \""
  done
  clock4=$(date +%s)

  durationwrite=$(expr $clock4 - $clock3)
  echo duration UPLOAD : $durationwrite seconds 
  
  globaldatasize=$(($SIZEFILE * $INPUTSIZE))
  transferrate=$((globaldatasize / $durationwrite))
  echo UPLOAD - transfer rate: $transferrate MB/s
 
}

echo RUN BENCH EFS I/O - Read / Write 

declare -a strSizeArray=("10k" "100k" "1m" "10m" "100m")
declare -a strSizeArrayDownload=("1m" "10m" "100m")
declare -a strSizeArrayUpload=("10k" "100k")

#njobs=(10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800)
njobs=(20 30 40 60 80 100 200 300 400 500 600 700 800)
#njobs=(40 60 80 400 600 800)
#sizeinputfile=(100 200 300 400 500 600 700 800)

echo LAUNCH EFS I/O 

cleanup

#testsshelltimeout
#runefsiobenchdownloadref
#runefsiobenchuploadref
#testparallelsshell

for ijob in "${njobs[@]}"
do
   echo ===============================
   echo nb jobs: $ijob
   runefsiobenchupload $ijob
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
