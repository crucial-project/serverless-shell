#!/usr/bin/env bash

JSONFILE=/ebs/home/ec2-user/exps/cr_data/apps/scan_data/test_80_40GB.json
MRTFILE=/ebs/home/ec2-user/exps/cr_data/apps/scan_data/2019-10-12.0500.mrt

port_scan_analysis()
{

  $NBJOBS=$1

  cat ${JSONFILE} | parallel -j$NBJOBS -I,, --env sshell "sshell \" go run main.go -routing -routing-mrt-file=${MRTFILE} \"" > annotated

  cat annotated | jq ".ip" | tr -d '"' > filefilter1
  cat annotated | jq -c ".zannotate.routing.asn" > filefiter2

  pr -mts, filefilter1 filefilter2 | awk -F',' "{ a[\$2]++; } END { for (n in a) print n \",\" a[n] } " | sort -k2 -n -t',' -r > as_popularity
}


port_scan_analysis $1
