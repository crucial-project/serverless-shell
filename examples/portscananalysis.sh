#!/usr/bin/env bash

EFSEC2PORTSCANPATH=/home/ec2-user/efs/portscan
EFSLAMBDAPORTSCANPATH=/mnt/efsimttsp/portscan

JSONFILEEC2=$EFSEC2PORTSCANPATH/test_80_40GB.json
JSONFILELAMBDA=$EFSLAMBDAPORTSCANPATH/test_80_40GB.json
MRTFILEEC2=$EFSEC2PORTSCANPATH/2019-10-12.0500.mrt
MRTFILELAMBDA=$EFSLAMBDAPORTSCANPATH/2019-10-12.0500.mrt

CHUNKS=10

cleanup()
{
 rm -rf $EFSEC2PORTSCANPATH/annotated $EFSEC2PORTSCANPATH/ckdir $EFSEC2PORTSCANPATH/filefilter* $EFSEC2PORTSCANPATH/as_popularity testckfile
 rm -rf ckdir
 rm -rf annotated
 rm -rf ckannotated*
 rm -f filefiter*
}

testckfile()
{
  seq 1 1 100 > testckfile
  FILE=testckfile 
  JOBS=10 
  SIZE=$(wc -l $FILE | cut -d" " -f1) 
  export CHUNK=$((SIZE/JOBS)) 
  echo Do parallel job -
  echo $FILE
  echo $JOBS
  echo $SIZE
  echo $CHUNK
  seq 1 1 ${JOBS} | parallel -n0 -j 1 --env sshell "sshell \" tail -n +\\\$(((PARALLEL_SEQ-1)*CHUNK)) ${FILE} | head -n ${CHUNK} \""
}

runlocalportscananalysis()
{
  clock1=`date +%s`
  head -n 100 $JSONFILE | zannotate -routing -routing-mrt-file=$MRTFILEEC2 -input-file-type=json > annotated 
  clock2=`date +%s`
  durationportscanannotate=`expr $clock2 - $clock1`
  echo "Local Port scan 1st part - annotate: $durationportscanannotate s" 
}

runlastlineportscananalysis()
{
  sshell "tail -n 1 ${JSONFILELAMBDA} | zannotate -routing -routing-mrt-file=$MRTFILELAMBDA -input-file-type=json "  > annotated
}

runlambdaportscananalysis()
{

  JOBS=$1

  echo STEP 1 - split input JSON file into chunks
  clock1=$(date +%s)
  mkdir $EFSEC2PORTSCANPATH/ckdir
  cd $EFSEC2PORTSCANPATH/ckdir
  split --verbose -n $CHUNKS $JSONFILEEC2 ckjson*
  for f in ckjson*; do cat $f | parallel -l 10000 > par$f ; done
  #split --verbose -n $CHUNKS $JSONFILEEC2 ckjson*
  cd -
  echo STEP 2 - annotate each chunk with sshell
  clock2=$(date +%s)
  ls $EFSEC2PORTSCANPATH/ckdir | parallel -j$JOBS -I,, --env sshell "sshell \" cat $EFSLAMBDAPORTSCANPATH/ckdir/,, | zannotate -routing -routing-mrt-file=$MRTFILELAMBDA -input-file-type=json \"" > $EFSEC2PORTSCANPATH/annotated
  echo STEP 3 - parse IP 
  clock3=$(date +%s)
  mkdir $EFSEC2PORTSCANPATH/annotateddir
  cd $EFSEC2PORTSCANPATH/annotateddir
  #cat $EFSEC2PORTSCANPATH/annotated | parallel -l 10000 > ckannotated
  split --verbose -n ${CHUNKS} $EFSEC2PORTSCANPATH/annotated ckannotated*
  for fannotated in ckannotated* ; do cat $fannotated | parallel -l 10000 > par$fannotated ; done
  cd -
  clock4=$(date +%s)
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat $EFSLAMBDAPORTSCANPATH/,, | jq \""".ip\""" | tr -d \"""'"\""' \"" > filefilter1
  #cat $EFSEC2PORTSCANPATH/annotated | parallel -j$NBJOBS -I,, --env sshell "sshell \" jq \""".ip\""" | tr -d \"""'"\""' \"" > $EFSEC2PORTSCANPATH/filefilter1
  echo STEP 4 - parse ASN
  clock5=$(date +%s)
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat $EFSLAMBDAPORTSCANPATH/,, | jq -c \""".zannotate.routing.asn\""" \"" > filefilter2
  #cat $EFSEC2PORTSCANPATH/annotated | parallel -j$NBJOBS -I,, --env sshell "sshell \" jq -c \""".zannotate.routing.asn\""" \"" > $EFSEC2PORTSCANPATH/filefiter2
  echo STEP 5 - Output popularity
  clock6=$(date +%s)
  pr -mts, filefilter1 filefilter2 | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > as_popularity
  mv as_popularity $EFSEC2PORTSCANPATH
  clock7=$(date +%s)

  durationportscansplitjson=$(expr $clock2 - $clock1)
  durationportscanannotate=$(expr $clock3 - $clock2)
  durationportscansplitannotate=$(expr $clock4 - $clock3)
  durationportscanfilter1=$(expr $clock5 - $clock4)
  durationportscanfilter2=$(expr $clock6 - $clock5)
  durationportscanpopularity=$(expr $clock7 - $clock6)
  durationportscanoverall=$(expr $clock7 - $clock1)

  echo "Port scan overall: $durationportscanoverall s"
  echo "Port scan 1st part - split: $durationportscansplit s" 
  echo "Port scan 2nd part - annotate: $durationportscanannotate s" 
  echo "Port scan 3rd part - split annotate: $durationportscansplitannotate s" 
  echo "Port scan 4th part - file filter 1: $durationportscanfilter1 s"
  echo "Port scan 5th part - file filter 2: $durationportscanfilter2 s"
  echo "Port scan 6th part - popularity: $durationportscanpopularity s"

}

#njobs=(20 30 40 60 80 100 200 300 400 500 600 700 800)
njobs=(100 200 300 400 500 600 700 800)

echo Run local port scan analysis
cleanup
#runlocalportscananalysis
echo Test Chunk file
#testckfile

echo Run serverless Port scan analysis with a range of #njobs
for ijob in "${njobs[@]}"
do
  echo =================================
  echo $ijob parallel jobs
  cleanup
  runlambdaportscananalysis $ijob
  #runportscananalysis $ijob > runportscananalysis.$ijob.njobs.out
  #bash examples/perfbreakdown.sh runthumbnails.$ijob.njobs.out $ijob
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i > thumbnails.perfbreakdown.$i.njobs.out
done
