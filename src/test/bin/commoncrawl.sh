#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${DIR}/config.sh

CCBASE="https://commoncrawl.s3.amazonaws.com"
CCMAIN="CC-MAIN-2019-43" # oct. 2019
INPUT=100
STEP=100
NUMJOBS=64 # Arbitrary number of jobs for stateful version
RANGE="-r 0-1000000"
curl -s ${CCBASE}/crawl-data/${CCMAIN}/warc.paths.gz \
    | zcat | head -n ${INPUT} > ${TMP_DIR}/index
curl -s ${CCBASE}/crawl-data/${CCMAIN}/wat.paths.gz \
    | zcat | head -n ${INPUT} > ${TMP_DIR}/index-wat

### 1 - average content size (stateless)

average(){
    while read l; do
	sshell "curl -s ${RANGE} ${CCBASE}/${l} | zcat -q | grep ^Content-Length " &
    done < ${TMP_DIR}/index | awk '{ sum += $2 } END { if (NR > 0) print int(sum / NR) }'
}
    
### 2 - average content size (stateful)

average_stateful(){
    sshell "counter -n average reset"
    while read l; do
	sshell "counter -n average increment -i \$(curl -s ${RANGE} ${CCBASE}/${l} | zcat | grep ^Content-Length | awk '{ sum += \$2 } END { if (NR > 0) print int(sum / NR) }')" 1> /dev/null &
    done < ${TMP_DIR}/index
    wait
    local lines=$(wc -l ${TMP_DIR}/index | awk '{print $1}')
    local total_average=$(sshell "counter -n average tally")
    echo $((total_average/lines))
}

### 3 - barrier gathering (toy example)

gathering(){
    LAMBDA=100
    BARRIER=$(uuid)
    seq 1 1 $((LAMBDA-1)) | parallel -n0 --env sshell sshell --async barrier -n ${BARRIER} -p ${LAMBDA}  await
    sshell barrier -n ${BARRIER} -p ${LAMBDA} await
}

### 4 - count IPs
# FIXME grep too old w. runtime=java8

# curl -s ${CCBASE}/crawl-data/${CCMAIN}/wet.paths.gz | zcat | head -n ${INPUT} > ${TMP_DIR}/index
count_ips(){
    LAMBDA=$(($(wc -l ${TMP_DIR}/index | awk '{print $1}')+1))
    BARRIER=$(uuid)
    sshell "map -n ips clear"
    cat ${TMP_DIR}/index | parallel -I,, --env sshell "sshell --async \"map -n ips mergeAll \\\$(curl -s ${RANGE} ${CCBASE}/,, | zcat | tr '[:space:]' '[\n*]' | grep -oE \\\"\\\b([0-9]{1,3}\\\.){3}[0-9]{1,3}\\\b\\\" | sort | uniq -c | sort -bnr | awk '{s=s\\\" -1 \\\"\\\$2\\\"=\\\"\\\$1}END{print s}') -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await \""
    sshell barrier -n ${BARRIER} -p ${LAMBDA} await
    sshell "map -n ips size"
}

## 5 - compute the popularity of each domain

domaincount(){
    while read l; do
	sshell "curl -s ${RANGE} ${CCBASE}/${l}
      	| zcat -q | tr \",\" \"\n\" 
	| sed 's/url\"/& /g' 
	| sed 's/:\"/& /g' 
	| grep \"url\" | grep http | awk '{print \$3}' | sed s/[\\\",]//g | awk -F/ '{print \$3}'  | awk '{for(i=1;i<=NF;i++) result[\$i]++} END {for(k in result) print k,result[k]}' | sort -k 2 -n -r" &
    done < ${TMP_DIR}/index-wat | awk '{result[$1]+=$2} END {for(k in result) print k,result[k]}' | sort -k 2 -n -r
}

##5 - compute the popularity of each domain (stateful: merge all)

domaincount_stateful_mergeall(){
  # declare a counter for JOB identifier
  sshell "counter -n average reset"
  sshell "counter -n idjob -c -1"
  # download wat.paths.gz un unzip it
  sshell "curl -s ${CCBASE}/crawl-data/${CCMAIN}/wat.paths.gz"
  sshell "gunzip wat.paths.gz"
  # Each job downloads a chunk of wat.paths
  for $id in $NUMJOBS; do
    # increment counter for jobs
    sshell "counter -n idjob increment -i"
    sshell "head -$($INPUT*$idjob) wat.paths
    | tail -$INPUT > ${TMP_DIR}/index-wat-chunk$idjob"
    while read l; do
      # a) Download metadata, b) unzip file, c) Search patterns "url" and "http", d) shorten url and keep domain name
      # e) count number of occurrences per domain
      sshell "curl -s ${RANGE} ${CCBASE}/${l}
      	| zcat -q | tr \",\" \"\n\"
	      | sed 's/url\"/& /g'
	      | sed 's/:\"/& /g'
	      | grep \"url\"
	      | grep http
	      | awk '{print \$3}'
	      | sed s/[\\\",]//g
	      | awk -F/ '{print \$3}'
	      | awk '{for(i=1;i<=NF;i++) result[\$i]++} END {for(k in result) print k,result[k]}'" &
    done < ${TMP_DIR}/index-wat-chunk$id | awk '{result[$1]+=$2} END {for(k in result) print k,result[k]}'
  done
  wait
  # concatenate files
  sshell "touch ${TMP_DIR}/index-wat"
  sshell "cat ${TMP_DIR}/index-wat-chunk* >> ${TMP_DIR}/index-wat"
  # Merge all: map -n <name> mergeAll <filename> -1 key -2 <function(sum,multiply,divide)>
  sshell "map -n domains clear"
  cat ${TMP_DIR}/index-wat | parallel -I,, --env sshell "sshell --async \"map -n domains mergeAll \\\cat ${TMP_DIR}/index-wat -1 $2 -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await \""
  sshell barrier -n ${BARRIER} -p ${LAMBDA} await
  sshell "map -n domains size"
  # sort
  sshell "cat ${TMP_DIR}/index-wat | sort -k 2 -n -r
  # for iter in numjobs:64
  # do
  #   M[iter-1].mergeAll(M[iter], Sum)
  # done
  # sort

}

## 5 - compute the popularity of each domain (stateful)

domaincount_stateful(){
  sshell "counter -n average reset"
  # declare a counter for JOB identifier
  sshell "counter -n id -c -1"
  while read l; do
    # increment counter for jobs
    sshell "counter -n id increment -i"
    # each job works on a specific range of the array to be computed, an offset is calculated for each job
	  sshell "curl -s ${RANGE} ${CCBASE}/${l}
    | zcat -q | tr \",\" \"\n\"
	  | sed 's/url\"/& /g'
	  | sed 's/:\"/& /g'
	  | grep \"url\" | grep http | awk '{print \$3}' | sed s/[\\\",]//g | awk -F/ '{print \$3}'  | awk '{for(i=1;i<=NF;i++) result[\id*NF+$i]++} END {for(k in result) print k,result[k]}' | sort -k 2 -n -r" &
  done < ${TMP_DIR}/index-wat | awk '{result[$1]+=$2} END {for(k in result) print k,result[k]}' | sort -k 2 -n -r
  wait
  # concatenate results array
  # perform a global sorting

}

## 7 - terasort: sort key,value dataset by key (stateless)

terasort(){

  # file placement
  sshell "split -l $KVRANGE/$NBNODES segment"

  # partitioning
  sshell "awk '{$SUBSET = $KVRANGE/$NBNODES}' ; iter=0 ; val=0"
  while val <= $HIGHVAL do
    sshell "partitionarray[iter,0] = val ; val = val+$SUBSET ; partitionarray[iter,1] = val ; iter = $((iter+1))"
  done

  #map
  for iter in $numnodes
  do
    # we read each line of each k file
    sshell "input = $filek ; index = 0"
    while IFS=read  -r line
    do
      sshell "echo $line"
      # extract key of key-value tuple on each line
      sshell "key=$( cut -d ',' -f 1)"
       # store key in each partition
      for k in $NBNODES
      do
        if [ key > partitionarray[k,0] -a key < partitionarray[k,1] ]; then
          sshell "partitionkv[k,index] = key ; index=$((index+1)) ; echo -n partitionkv[k,index] | echo "," >> $filemapk"
        fi
      done
    done
  done

  #shuffle
  for i in $NBNODES do
    for k in $NBNODES do
      sshell "index = 0 ; nodeskv[k,index] = partitionkv[k,index] ; index=$((index+1)) ; size[k] = index"
    done
  done

  #reduce
  for k in $NBNODES do
    sshell "IFS=$'\n' sortedkv=($(sort <<< "${nodeskv[k,*]}")); unset IFS"
  done
}

# average_stateful
# gathering
count_ips

