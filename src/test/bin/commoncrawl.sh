#!/usr/bin/env bash -x

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
    cat ${TMP_DIR}/index | parallel -I,, --env sshell "sshell --async \"map -n ips mergeAll \\\$(curl -s ${RANGE} ${CCBASE}/,, 
    | zcat 
    | tr '[:space:]' '[\n*]' 
    | grep -oE \\\"\\\b([0-9]{1,3}\\\.){3}[0-9]{1,3}\\\b\\\" 
    | sort 
    | uniq -c 
    | sort -bnr 
    | awk '{s=s\\\" -1 \\\"\\\$2\\\"=\\\"\\\$1}END{print s}') -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await \""
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
	| grep \"url\" 
  | grep http 
  | awk '{print \$3}' 
  | sed s/[\\\",]//g 
  | awk -F/ '{print \$3}'  
  | awk '{for(i=1;i<=NF;i++) result[\$i]++} END {for(k in result) print k,result[k]}' 
  | sort -k 2 -n -r" &
    done < ${TMP_DIR}/index-wat | awk '{result[$1]+=$2} END {for(k in result) print k,result[k]}' | sort -k 2 -n -r
}

##5 - compute the popularity of each domain (stateful: merge all)

domaincount_stateful_mergeall(){
    # declare a counter for JOB identifier
    BARRIER=$(uuid)
    #LAMBDA=$(($(wc -l domainstats | awk '{print $1}')+1))
    LAMBDA=$(($(wc -l ${TMP_DIR}/index-wat | awk '{print $1}')+1))
    map -n mapdomains clear
    echo "Parse WAT ..."
    while read l; do
	echo "read WAT line"
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
	      | awk '{for(i=1;i<=NF;i++) result[\$i]++}END{for(k in result) print k,result[k]}'" &
    done < ${TMP_DIR}/index-wat | awk '{result[$1]+=$2} END {for(k in result) print k,result[k]}' > domainstats
    #head -n 100 domainstats > domainstatsredux
    wait
    # Merge all: map -n <name> mergeAll <filename> -1 map<domainname,number> -2 <function(sum,multiply,divide)>
    #sshell "map -n domainstats clear"
    map -n mapdomains size
    #LAMBDA=$(($(wc -l domainstats | awk '{print $1}')+1))
    echo "barrier ID: $BARRIER"
    echo "lambda: $LAMBDA"
    echo "Before Merge All"
    count=0
    head -n 200 domainstats2 > domainstats2redux
    while IFS= read -r line; do
      echo "read line of index"
      echo "line: $line"
      key=$(echo $line | awk '{print $1}')
      val=$(echo $line | awk '{print $2}')
      echo "key: $key"
      echo "value: $val"
      #awk -v col1=1 -v col2=2 '{print $col1, $col2}'
      map -n mapdomains mergeAll -1 $key=$val -2 sum
      echo count: $count
      ((count=count+1))
    done < domainstats2redux
    echo "After Merge All"
    #barrier -n ${BARRIER} -p ${LAMBDA} await
    map -n mapdomains size
    #cat domainstatspar | parallel -n0 --env sshell sshell --async barrier -n ${BARRIER} -p ${LAMBDA}  await
    #cat ${TMP_DIR}/index-wat | parallel -I,, --env sshell "sshell --async \"map -n domainstats mergeAll 
    #cat domainstatsredux | parallel -I,, --env sshell "sshell --async \"map -n mapdomains mergeAll 
    #| awk '{s=s\\\" -1 \\\"\\\$2\\\"=\\\"\\\$1}END{print s}' -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await \""
    #sshell barrier -n ${BARRIER} -p ${LAMBDA} await
    #echo "After Merge All"
    #sshell "map -n domainstats size"
    #sshell "map -n mapdomains size"
    # Move domainstats to AWS S3
    touch domainstats.sorted
    #aws s3 mv domainstats s3://amaheo/domainstats
    #aws s3api put-object-acl --bucket amaheo --key domainstats --acl public-read
    aws s3 mv domainstats.sorted s3://amaheo/domainstats.sorted
    aws s3api put-object-acl --bucket amaheo --key domainstats.sorted --acl public-read
    # sort
    echo "Sort domains"
    #sshell "aws s3 cp s3://amaheo/domainstats ."
    #sshell "cat s3://amaheo/domainstats | sort -k 2 -n -r > domainstats.sorted"
    #sshell "curl -s https://amaheo.s3.amazonaws.com/domainstats | sort -k 2 -n -r > domainstats.sorted"
    curl -s https://amaheo.s3.amazonaws.com/domainstats | sort -k 2 -n -r > domainstats.sorted

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
  #sshell "split -l $KVRANGE/$NBNODES segment"

  # partitioning
  #sshell "awk '{$SUBSET = $KVRANGE/$NBNODES}' ; iter=0 ; val=0"
  #while val <= $HIGHVAL do
    sshell "partitionarray[iter,0] = val ; val = val+$SUBSET ; partitionarray[iter,1] = val ; iter = $((iter+1))"
  #done

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
  #for i in $NBNODES do
  #  for k in $NBNODES do
  #    sshell "index = 0 ; nodeskv[k,index] = partitionkv[k,index] ; index=$((index+1)) ; size[k] = index"
  #  done
  #done

  #reduce
  #for k in $NBNODES do
  #  sshell "IFS=$'\n' sortedkv=($(sort <<< "${nodeskv[k,*]}")); unset IFS"
  #done
}

#average_stateful
#gathering
#count_ips
#domaincount
domaincount_stateful_mergeall

