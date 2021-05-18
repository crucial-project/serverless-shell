#!/usr/bin/env bash

EFSEC2PORTSCANPATH=/home/ec2-user/efs/portscan
EFSLAMBDAPORTSCANPATH=/mnt/efsimttsp/portscan

JSONFILEEC2=$EFSEC2PORTSCANPATH/test_80_40GB.json
JSONFILELAMBDA=$EFSLAMBDAPORTSCANPATH/test_80_40GB.json
MRTFILEEC2=$EFSEC2PORTSCANPATH/2019-10-12.0500.mrt
MRTFILELAMBDA=$EFSLAMBDAPORTSCANPATH/2019-10-12.0500.mrt

CHUNKS=1000

cleanup()
{
 echo cleanup
 #rm -rf $EFSEC2PORTSCANPATH/annotated $EFSEC2PORTSCANPATH/ckdir $EFSEC2PORTSCANPATH/filefilter* $EFSEC2PORTSCANPATH/as_popularity testckfile
 rm -rf $EFSEC2PORTSCANPATH/annotated $EFSEC2PORTCANPATH/annotateddir/* $EFSEC2PORTSCANPATH/filefilter* $EFSEC2PORTSCANPATH/as_popularity testckfile
 rm -rf $EFSEC2PORTSCANPATH/annotateddir
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

splitjsonincks()
{

  echo STEP 1 - split input JSON file into chunks
  #mkdir $EFSEC2PORTSCANPATH/ckdir
  #cd $EFSEC2PORTSCANPATH/ckdir
  #split --verbose -n $CHUNKS $JSONFILEEC2 ckjson*
  #for f in ckjson*; do cat $f | parallel -l 10000 > par$f ; done
  #cd -

}

annotatejson()
{
  echo STEP 2 - annotate each chunk with sshell
  mkdir ${EFSEC2PORTSCANPATH}/annotateddir
  ls ${EFSEC2PORTSCANPATH}/ckdir | parallel -j$JOBS -I,, --env sshell "sshell \" cat ${EFSLAMBDAPORTSCANPATH}/ckdir/,, | zannotate -routing -routing-mrt-file=$MRTFILELAMBDA -input-file-type=json \" > ${EFSLAMBDAPORTSCANPATH}/annotateddir/annotated-\${PARALLEL_SEQ}"
}

extractip()
{
  echo STEP 3 - parse IP 
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat ,, | jq \""".ip\""" | tr -d \"""'"\""' \"" > filefilter1
}

extractasn()
{
  echo STEP 4 - parse ASN
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat ,, | jq -c \""".zannotate.routing.asn\""" \"" > filefilter2
}

processaspopularity()
{
  echo STEP 5 - Output popularity
  pr -mts, filefilter1 filefilter2 | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > as_popularity
  mv as_popularity $EFSEC2PORTSCANPATH
}

runlambdaportscananalysis()
{
  echo Run Port scan analysis
  JOBS=$1

  clock1=$(date +%s)
  #$(splitjsonincks)
  clock2=$(date +%s)
  echo STEP 2 - annotate each chunk with sshell
  mkdir ${EFSEC2PORTSCANPATH}/annotateddir
  chmod 777 ${EFSEC2PORTSCANPATH}/annotateddir
  ls ${EFSEC2PORTSCANPATH}/ckdir > cklist.out
  head -n 40 cklist.out | parallel -j$JOBS -I,, --env sshell "sshell \" cat ${EFSLAMBDAPORTSCANPATH}/ckdir/,, | zannotate -routing -routing-mrt-file=$MRTFILELAMBDA -input-file-type=json \" > ${EFSEC2PORTSCANPATH}/annotated-\${PARALLEL_SEQ}"
  clock3=$(date +%s)
  echo STEP 3 - parse IP 
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat ,, | jq \""".ip\""" | tr -d \"""'"\""' \"" > filefilter1
  clock4=$(date +%s)
  echo STEP 4 - parse ASN
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat ,, | jq -c \""".zannotate.routing.asn\""" \"" > filefilter2
  clock5=$(date +%s)
  echo $(processaspopularity)
  echo STEP 5 - Output popularity
  pr -mts, filefilter1 filefilter2 | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > as_popularity
  mv as_popularity $EFSEC2PORTSCANPATH
  clock6=$(date +%s)

  durationportscansplitjson=$(expr $clock2 - $clock1)
  durationportscanannotate=$(expr $clock3 - $clock2)
  durationportscanextractip=$(expr $clock4 - $clock3)
  durationportscanextractasn=$(expr $clock5 - $clock4)
  durationportscanpopularity=$(expr $clock6 - $clock5)
  durationportscanoverall=$(expr $clock6 - $clock1)

  echo "Port scan overall: $durationportscanoverall s"
  echo "Port scan 1st part - split: $durationportscansplitjson s" 
  echo "Port scan 2nd part - annotate: $durationportscanannotate s" 
  echo "Port scan 3rd part - extract ip: $durationportscanextractip s"
  echo "Port scan 4th part - extract asn: $durationportscanextractasn s"
  echo "Port scan 5th part - popularity: $durationportscanpopularity s"

}

njobs=(20 30 40 60 80 100 200 300 400 500 600 700 800)
#njobs=(100 200 300 400 500 600 700 800)

#cleanup
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
