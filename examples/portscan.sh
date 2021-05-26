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
 rm -rf $EFSEC2PORTSCANPATH/annotated 
 rm -rf $EFSEC2PORTSCANPATH/ckdir 
 rm -rf $EFSEC2PORTSCANPATH/annotateddir 
 rm -rf $EFSEC2PORTSCANPATH/ipdir 
 rm -rf $EFSEC2PORTSCANPATH/asndir 
 rm -rf $EFSEC2PORTSCANPATH/as_popularity
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

runlocalseqportscananalysis()
{
  echo Run Local / SEQ Port Scan analysis
  clock1=$(date +%s)
  echo STEP 1 - Annotate
  cat $JSONFILEEC2 | zannotate -routing -routing-mrt-file=$MRTFILEEC2 -input-file-type=json > $EFSEC2PORTSCANPATH/annotated 
  clock2=$(date +%s)
  echo STEP 2 - Extract IP
  cat $EFSEC2PORTSCANPATH/annotated | jq ".ip" | tr -d '"' > $EFSEC2PORTSCANPATH/extract_ip
  clock3=$(date +%s)
  echo STEP 3 - Extract ASN
  cat $EFSEC2PORTSCANPATH/annotated | jq -c ".zannotate.routing.asn" > $EFSEC2PORTSCANPATH/extract_asn
  clock4=$(date +%s)
  echo STEP 4 - Calculate popularity
  pr -mts, $EFSEC2PORTSCANPATH/extract_ip $EFSEC2PORTSCANPATH/extract_asn | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > $EFSEC2PORTSCANPATH/as_popularity
  clock5=$(date +%s)

  durationportscanannotate=$(expr $clock2 - $clock1)
  durationportscanextractip=$(expr $clock3 - $clock2)
  durationportscanextractasn=$(expr $clock4 - $clock3)
  durationportscanpopularity=$(expr $clock5 - $clock4)
  durationportscanoverall=$(expr $clock5 - $clock4)

  echo "Local / SEQ Port scan - overall: $durationportscanoverall s" 
  echo "Local / SEQ Port scan - annotate: $durationportscanannotate s" 
  echo "Local / SEQ Port scan - extract IP: $durationportscanextractip s" 
  echo "Local / SEQ Port scan - extract ASN: $durationportscanextractasn s" 
  echo "Local / SEQ Port scan - Popularity: $durationportscanpopularity s" 
}

runlocalparportscananalysis()
{
  echo Run local / PARALLEL Port scan analysis 
  #JOBS=$1
  JOBS=$(lscpu | grep "Processeur(s)" | awk '{print $2}')
  echo Nombre de jobs: $JOBS

  echo STEP 1 - split input JSON file into chunks
  clock1=$(date +%s)
  mkdir $EFSEC2PORTSCANPATH/ckdir
  chmod 777 $EFSEC2PORTSCANPATH/ckdir
  cd $EFSEC2PORTSCANPATH/ckdir
  cat $JSONFILEEC2 | parallel -j200 --pipe --block 40M "cat > ${EFSEC2PORTSCANPATH}/ckdir/ckjson_{#}"
  #split --verbose -n $CHUNKS $JSONFILEEC2 ckjson
  cd -
  clock2=$(date +%s)
  durationportscansplitjson=$(expr $clock2 - $clock1)
  echo "Port scan 1st part - split: $durationportscansplitjson s" 
  echo STEP 2 - annotate each chunk with sshell
  mkdir ${EFSEC2PORTSCANPATH}/annotateddir
  chmod 777 ${EFSEC2PORTSCANPATH}/annotateddir
  ls ${EFSEC2PORTSCANPATH}/ckdir > cklist.out
  echo size of input elements: 
  cat cklist.out | wc -l
  cat cklist.out | parallel -j$JOBS -I,,  "cat ${EFSEC2PORTSCANPATH}/ckdir/,, | zannotate -routing -routing-mrt-file=$MRTFILEEC2 -input-file-type=json > $EFSEC2PORTSCANPATH/annotateddir/annotated_\${PARALLEL_SEQ}"
  clock3=$(date +%s)
  echo STEP 3 - parse IP 
  mkdir $EFSEC2PORTSCANPATH/ipdir
  chmod 777 $EFSEC2PORTSCANPATH/ipdir
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, "cat ${EFSEC2PORTSCANPATH}/annotateddir/,, | jq \".ip\" > $EFSEC2PORTSCANPATH/ipdir/ip_\${PARALLEL_SEQ}" 
  clock4=$(date +%s)
  echo STEP 4 - parse ASN
  mkdir $EFSEC2PORTSCANPATH/asndir
  chmod 777 $EFSEC2PORTSCANPATH/asndir
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, "cat ${EFSEC2PORTSCANPATH}/annotateddir/,, | jq -c \".zannotate.routing.asn\" > $EFSEC2PORTSCANPATH/asndir/asn_\${PARALLEL_SEQ} "  
  clock5=$(date +%s)
  #echo $(processaspopularity)
  echo STEP 5 - Output popularity
  cat $EFSEC2PORTSCANPATH/ipdir/ip_* > $EFSEC2PORTSCANPATH/ipdir/ip_aggr
  cat $EFSEC2PORTSCANPATH/asndir/asn_* > $EFSEC2PORTSCANPATH/asndir/asn_aggr
  pr -mts, $EFSEC2PORTSCANPATH/ipdir/ip_aggr $EFSEC2PORTSCANPATH/asndir/asn_aggr | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > $EFSEC2PORTSCANPATH/as_popularity
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


runlastlineportscananalysis()
{
  sshell "tail -n 1 ${JSONFILELAMBDA} | zannotate -routing -routing-mrt-file=$MRTFILELAMBDA -input-file-type=json "  > annotated
}

processaspopularity()
{
  echo STEP 5 - Output popularity
  pr -mts, filefilter1 filefilter2 | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > as_popularity
  mv as_popularity $EFSEC2PORTSCANPATH
}

runlambdaportscananalysisstateful()
{
  echo Run Port scan analysis - version stateful
  JOBS=$1

  echo STEP 1 - split input JSON file into chunks
  clock1=$(date +%s)
  mkdir $EFSEC2PORTSCANPATH/ckdir
  chmod 777 $EFSEC2PORTSCANPATH/ckdir
  cd $EFSEC2PORTSCANPATH/ckdir
  cat $JSONFILEEC2 | parallel -j200 --pipe --block 40M "cat > ${EFSEC2PORTSCANPATH}/ckdir/ckjson_{#}"
  #split --verbose -n $CHUNKS $JSONFILEEC2 ckjson
  cd -
  clock2=$(date +%s)
  durationportscansplitjson=$(expr $clock2 - $clock1)
  echo "Port scan 1st part - split: $durationportscansplitjson s" 
  echo STEP 2 - annotate each chunk with sshell
  mkdir ${EFSEC2PORTSCANPATH}/annotateddir
  chmod 777 ${EFSEC2PORTSCANPATH}/annotateddir
  ls ${EFSEC2PORTSCANPATH}/ckdir > cklist.out
  echo size of input elements: 
  cat cklist.out | wc -l
  cat cklist.out | parallel -j$JOBS -I,, --env sshell "sshell \" cat ${EFSLAMBDAPORTSCANPATH}/ckdir/,, | zannotate -routing -routing-mrt-file=$MRTFILELAMBDA -input-file-type=json > $EFSLAMBDAPORTSCANPATH/annotateddir/annotated_\${PARALLEL_SEQ} \""
  clock3=$(date +%s)
  echo STEP 3 - parse IP 
  mkdir $EFSEC2PORTSCANPATH/ipdir
  chmod 777 $EFSEC2PORTSCANPATH/ipdir
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat ${EFSLAMBDAPORTSCANPATH}/annotateddir/,, | jq \""".ip\""" > $EFSLAMBDAPORTSCANPATH/ipdir/ip_\${PARALLEL_SEQ} \"" 
  clock4=$(date +%s)
  echo STEP 4 - parse ASN
  mkdir $EFSEC2PORTSCANPATH/asndir
  chmod 777 $EFSEC2PORTSCANPATH/asndir
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat ${EFSLAMBDAPORTSCANPATH}/annotateddir/,, | jq -c \""".zannotate.routing.asn\""" > $EFSLAMBDAPORTSCANPATH/asndir/asn_\${PARALLEL_SEQ} \""  
  clock5=$(date +%s)
  #echo $(processaspopularity)
  echo STEP 5 - Output popularity
  cat $EFSEC2PORTSCANPATH/ipdir/ip_* > $EFSEC2PORTSCANPATH/ipdir/ip_aggr
  cat $EFSEC2PORTSCANPATH/asndir/asn_* > $EFSEC2PORTSCANPATH/asndir/asn_aggr
  #pr -mts, $EFSEC2PORTSCANPATH/ipdir/ip_aggr $EFSEC2PORTSCANPATH/asndir/asn_aggr | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > $EFSEC2PORTSCANPATH/as_popularity
  pr -mts, $EFSEC2PORTSCANPATH/ipdir/ip_aggr $EFSEC2PORTSCANPATH/asndir/asn_aggr  > $EFSEC2PORTSCANPATH/as_popularity
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


runlambdaportscananalysistateless()
{
  echo Run Port scan analysis - version stateless
  JOBS=$1

  echo STEP 1 - split input JSON file into chunks
  clock1=$(date +%s)
  mkdir $EFSEC2PORTSCANPATH/ckdir
  chmod 777 $EFSEC2PORTSCANPATH/ckdir
  cd $EFSEC2PORTSCANPATH/ckdir
  cat $JSONFILEEC2 | parallel -j200 --pipe --block 40M "cat > ${EFSEC2PORTSCANPATH}/ckdir/ckjson_{#}"
  split --verbose -n $CHUNKS $JSONFILEEC2 ckjson
  cd -
  clock2=$(date +%s)
  durationportscansplitjson=$(expr $clock2 - $clock1)
  echo "Port scan 1st part - split: $durationportscansplitjson s" 
  echo STEP 2 - annotate each chunk with sshell
  mkdir ${EFSEC2PORTSCANPATH}/annotateddir
  chmod 777 ${EFSEC2PORTSCANPATH}/annotateddir
  ls ${EFSEC2PORTSCANPATH}/ckdir > cklist.out
  echo size of input elements: 
  cat cklist.out | wc -l
  cat cklist.out | parallel -j$JOBS -I,, --env sshell "sshell \" cat ${EFSLAMBDAPORTSCANPATH}/ckdir/,, | zannotate -routing -routing-mrt-file=$MRTFILELAMBDA -input-file-type=json > $EFSLAMBDAPORTSCANPATH/annotateddir/annotated_\${PARALLEL_SEQ} \""
  clock3=$(date +%s)
  echo STEP 3 - parse IP 
  mkdir $EFSEC2PORTSCANPATH/ipdir
  chmod 777 $EFSEC2PORTSCANPATH/ipdir
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat ${EFSLAMBDAPORTSCANPATH}/annotateddir/,, | jq \""".ip\""" > $EFSLAMBDAPORTSCANPATH/ipdir/ip_\${PARALLEL_SEQ} \"" 
  clock4=$(date +%s)
  echo STEP 4 - parse ASN
  mkdir $EFSEC2PORTSCANPATH/asndir
  chmod 777 $EFSEC2PORTSCANPATH/asndir
  ls $EFSEC2PORTSCANPATH/annotateddir | parallel -j$JOBS -I,, --env sshell "sshell \" cat ${EFSLAMBDAPORTSCANPATH}/annotateddir/,, | jq -c \""".zannotate.routing.asn\""" > $EFSLAMBDAPORTSCANPATH/asndir/asn_\${PARALLEL_SEQ} \""  
  clock5=$(date +%s)
  #echo $(processaspopularity)
  echo STEP 5 - Output popularity
  cat $EFSEC2PORTSCANPATH/ipdir/ip_* > $EFSEC2PORTSCANPATH/ipdir/ip_aggr
  cat $EFSEC2PORTSCANPATH/asndir/asn_* > $EFSEC2PORTSCANPATH/asndir/asn_aggr
  pr -mts, $EFSEC2PORTSCANPATH/ipdir/ip_aggr $EFSEC2PORTSCANPATH/asndir/asn_aggr | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > $EFSEC2PORTSCANPATH/as_popularity
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

#njobs=(60 80 100 200 400 600 800)
#njobs=(20)

cleanup
runlocalparportscananalysis
#echo Test Chunk file
#testckfile

echo Run serverless Port scan analysis with a range of #njobs
for ijob in "${njobs[@]}"
do
  echo =================================
  echo $ijob parallel jobs
  #cleanup
  #runlocalparportscananalysis $ijob
  #runportscananalysis $ijob > runportscananalysis.$ijob.njobs.out
  #bash examples/perfbreakdown.sh runthumbnails.$ijob.njobs.out $ijob
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i > thumbnails.perfbreakdown.$i.njobs.out
done
