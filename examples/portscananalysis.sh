#!/usr/bin/env bash

EFSEC2PORTSCANPATH=/home/ec2-user/efs/portscan
EFSLAMBDAPORTSCANPATH=/mnt/efsimttsp/portscan

JSONFILE=$EFSEC2PORTSCANPATH/test_80_40GB.json
MRTFILEEC2=$EFSEC2PORTSCANPATH/2019-10-12.0500.mrt
MRTFILELAMBDA=$EFSLAMBDAPORTSCANPATH/2019-10-12.0500.mrt

cleanup()
{
 rm -f $EFSEC2PORTSCANPATH/annotated $EFSEC2PORTSCANPATH/filefilter* $EFSEC2PORTSCANPATH/as_popularity
}

runlocalportscananalysis()
{

  clock1=`date +%s`
  head -n 1000000 $JSONFILE | zannotate -routing -routing-mrt-file=$MRTFILEEC2 -input-file-type=json > annotated 
  clock2=`date +%s`
  durationportscanannotate=`expr $clock2 - $clock1`
  echo "Local Port scan 1st part - annotate: $durationportscanannotate s" 
}


runlambdaportscananalysis()
{

  NBJOBS=$1

  clock1=`date +%s`
  #cat $JSONFILE | parallel -j$NBJOBS -I,, --env sshell "sshell \" zannotate -routing -routing-mrt-file=$MRTFILELAMBDA -input-file-type=json \"" > $EFSEC2PORTSCANPATH/annotated
  cat $JSONFILE | parallel -j$NBJOBS -I,, --env sshell "sshell \" zannotate -routing -routing-mrt-file=$MRTFILELAMBDA -input-file-type=json \"" 
  clock2=`date +%s`
  cat $EFSEC2PORTSCANPATH/annotated | parallel -j$NBJOBS -I,, --env sshell "sshell \" jq \""".ip\""" | tr -d \"""'"\""' \"" > $EFSEC2PORTSCANPATH/filefilter1
  clock3=`date +%s`
  cat $EFSEC2PORTSCANPATH/annotated | parallel -j$NBJOBS -I,, --env sshell "sshell \" jq -c \""".zannotate.routing.asn\""" \"" > $EFSEC2PORTSCANPATH/filefiter2
  clock4=`date +%s`
  pr -mts, filefilter1 filefilter2 | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > $EFSEC2PORTSCANPATH/as_popularity
  clock5=`date +%s`

  durationportscanannotate=`expr $clock2 - $clock1`
  durationportscanfilter1=`expr $clock3 - $clock2`
  durationportscanfilter2=`expr $clock4 - $clock3`
  durationportscanpopularity=`expr $clock5 - $clock4`
  durationportscanoverall=`expr $clock5 - $clock1`

  echo "Port scan overall: $durationportscanoverall s"
  echo "Port scan 1st part - annotate: $durationportscanannotate s" 
  echo "Port scan 2nd part - file filter 1: $durationportscanfilter1 s"
  echo "Port scan 3rd part - file filter 2: $durationportscanfilter2 s"
  echo "Port scan 4th part - popularity: $durationportscanpopularity s"

}

njobs=(20 30 40 60 80 100 200 300 400 500 600 700 800)

echo Run local port scan analysis
#cleanup
#runlocalportscananalysis

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
