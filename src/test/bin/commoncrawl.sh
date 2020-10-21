#!/usr/bin/env bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${DIR}/config.sh

CCBASE="https://commoncrawl.s3.amazonaws.com"
CCMAIN="CC-MAIN-2019-43" # oct. 2019
INPUT=300
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
    | awk '{s=s\\\" -1 \\\"\\\$2\\\"=\\\"\\\$1}END{print s}') -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await \"" > ipsmergeall.out
    sshell barrier -n ${BARRIER} -p ${LAMBDA} await
    sshell "map -n ips size"
}

count_ips_local(){
    LAMBDA=$(($(wc -l ${TMP_DIR}/index | awk '{print $1}')+1))
    BARRIER=$(uuid)
    map -n ips clear
    cat ${TMP_DIR}/index | parallel map -n ips mergeAll $(curl -s ${RANGE} ${CCBASE}/,, 
    | zcat 
    | tr '[:space:]' '[\n*]' 
    | grep -oE \\\"\\\b([0-9]{1,3}\\\.){3}[0-9]{1,3}\\\b\\\" 
    | sort 
    | uniq -c 
    | sort -bnr 
    | awk '{s=s\\\" -1 \\\"\\\$2\\\"=\\\"\\\$1}END{print s}') -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await > ipsmergeall.out
    #sshell barrier -n ${BARRIER} -p ${LAMBDA} await
    map -n ips size
}

count_ips_basic(){
    LAMBDA=$(($(wc -l ips.out | awk '{print $1}')+1))
    BARRIER=$(uuid)
    echo "clear map mapips"
    map -n mapips clear
    map -n mapips size
    echo "Perform Merge All"
    map -n mapips mergeAll $(cat ips.out | awk '{s=s" -1 "$2"="$1}END{print s}') -2 sum > ipsmergeall.out
    #map -n mapips mergeAll $(head -n 10 ips.out | awk '{s=s" -1 "$2"="$1}END{print s}') -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await > ipsmergeall.out
    map -n mapips size
}

count_ips_2(){
    LAMBDA=$(($(wc -l ${TMP_DIR}/index | awk '{print $1}')+1))
    BARRIER=$(uuid)
    while read l; do
       curl -s ${RANGE} ${CCBASE}/${l} | zcat | tr '[:space:]' '[\n*]' | grep -oE "b([0-9]{1,3}.){3}[0-9]{1,3}b" | sort | uniq -c | sort -bnr
    done < ${TMP_DIR}/index > ips.out 
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

##5 - compute the popularity of each domain (merge all)

domaincount_mergeall(){
 LAMBDA=$(($(wc -l ${TMP_DIR}/index-wat | awk '{print $1}')+1))
 BARRIER=$(uuid)
 sshell "map -n mapdomains clear"
 cat ${TMP_DIR}/index-wat | parallel -I,, --env sshell "sshell --async \"map -n mapdomains mergeAll \\\$(curl -s ${RANGE} ${CCBASE}/,, 
   	| zcat -q | tr \",\" \"\n\"
	| sed 's/url\"/& /g'
	| sed 's/:\"/& /g'
	| grep \"url\"
	| grep http
	| awk '{print \$3}'
	| sed s/[\\\",]//g
	| awk -F/ '{print \$3}'
	| awk '{for(i=1;i<=NF;i++) result[\$i]++}END{for(k in result) print k,result[k]}'
        | awk '{s=s\\\" -1 \\\"\\\$1\\\"=\\\"\\\$2}END{print s}') -2 sum \"" > domainstats
 #sshell barrier -n ${BARRIER} -p ${LAMBDA} await
 sshell "map -n mapdomains size"
}

##6 - compute the popularity of each domain (stateful: merge all)

domaincount_wo_compute(){
  while read l; do
    sshell "sleep 0.01" 
  done < ${TMP_DIR}/index-wat
}

sshell_echo(){
echo "Test sshell echo"

sshell "
time1=`date +%s`
echo test
sleep 2
time2=`date +%s`
"

echo "Wait 2 sec"
wait
sleep 2

sshell "
echo sshell
time3=`date +%s`
echo test 2
sleep 3
time4=`date +%s`
echo \$time3
echo \$time4
spenttime=\`expr \$time4 - \$time3\`
echo in sshell: spent time is \$spenttime seconds
"

ssh aurele@stark1.int-evry.fr "echo ssh this is my_server; abc=2 ; sleep 3 ; echo abc is \$abc"
sshell "echo sshell this is my_server; abc=2 ; sleep 3 ; echo abc is \$abc"

ssh aurele@stark1.int-evry.fr "echo ssh; date1=`date +%s`; echo date 1 is \$date1; for i in {1..1000}; do echo $i; done ; date2=`date +%s`; echo date 2 is \$date2; spenttime=\`expr \$date2 - \$date1\`; echo spent time is \$spenttime seconds"


sshell "echo sshell; date1=`date +%s` ; echo date 1 is \$date1 ; date2=`date +%s` ; echo date 2 is \$date2 ; spenttime=\`expr \$date2 - \$date1\` ; echo spent time is \$spenttime seconds" > datesshell.out

echo "Attempt to call ssh with sleep"
ssh aurele@stark1.int-evry.fr "sleep 3"

#icount = 0
#while read l; do
#  sshell "curl -s ${RANGE} ${CCBASE}/${l} > watcontent.out"
#done < ${TMP_DIR}/index-wat	

#while read l; do
#  sshell "echo sshell; date1=`date +%s`; curl -s ${RANGE} ${CCBASE}/${l} ; echo date 1 is \$date1; date2=`date +%s`; echo date 2 is \$date2; spenttime=\`expr \$date2 - \$date1\`; echo spent time is \$spenttime seconds" 
#done < ${TMP_DIR}/index-wat

sshell "echo sshell; date1=`date +%s`; echo date is \$date1"

time5=`date +%s`
time6=`date +%s`
echo "time is `expr $time6 - $time5` seconds"
}

domaincount_breakdown(){
  echo "domaincount_breakdown"
  touch breakdown.out
  echo "breakdown" > breakdown.out
  icount=0
  while read l; do
	  sshell "(clock1=`date +%s` ; curl -s ${RANGE} ${CCBASE}/${l} ; clock2=`date +%s` ; durationcurl=\`expr \$clock2 - \$clock1\` ; echo durationcurl: \$durationcurl seconds > /tmp/durationcurl) | (clock3=`date +%s` ; zcat -q |  tr \",\" \"\n\" | sed 's/url\"/& /g' | sed 's/:\"/& /g' | grep \"url\" | grep http | awk '{print \$3}' | sed s/[\\\",]//g | awk -F/ '{print \$3}' | awk '{for(i=1;i<=NF;i++) result[\$i]++}END{for(k in result) print k,result[k]}' ; clock4=`date +%s` ; durationprocess=\`expr \$clock4 - \$clock3\`  ; cat /tmp/durationcurl ; echo durationprocess: \$durationprocess seconds) "
	 let "icount+=1"
	 echo counter: $icount 
  done < ${TMP_DIR}/index-wat
}

domaincount_breakdown_2(){ 
  echo "domaincount breakdown"
  touch domaincountbreakdown.out
  while read l; do
	  sshell "clock1=`date +%s` ; storecurl=$(curl -s ${RANGE} ${CCBASE}/${l}) ; clock2=`date +%s` ; echo $storecurl | zcat -q | tr \",\" \"\n\" | sed 's/url\"/& /g' | sed 's/:\"/& /g' | grep \"url\" | grep http | awk '{print \$3}' | sed s/[\\\",]//g | awk -F/ '{print \$3}' | awk '{for(i=1;i<=NF;i++) result[\$i]++}END{for(k in result) print k,result[k]}' ; clock3=`date +%s` ; echo clock 1: \$clock1 ; echo clock 2: \$clock2 ; echo clock 3: \$clock3 ; times3=\`expr \$clock2 - \$clock1\` ; timecompute=\`expr \$clock3 - \$clock2\` ; echo time to read S3: \$times3 nanoseconds ; echo time to parse: \$timecompute nanoseconds "
  done < ${TMP_DIR}/index-wat > breakdown.out
  clock4=`date +%s`
  wait 
  clock5=`date +%s`
  echo Barrier time was `expr $clock5 - $clock4` seconds
}

domaincount_stateful_mergeall(){
    # declare a counter for JOB identifier
    BARRIER=$(uuid)
    LAMBDA=$(($(wc -l ${TMP_DIR}/index-wat | awk '{print $1}')+1))
    map -n mapdomains clear
    echo "Parse WAT ..."
    start=`date +%s%N`
    startinvoc=`date +%s%N`
    endinvoc=`date +%s%N`
    while read l; do
	echo "read WAT line"
        # a) Download metadata, b) unzip file, c) Search patterns "url" and "http", d) shorten url and keep domain name
       	# e) count number of occurrences per domain
        startinvoc=`date +%s%N`
	sshell "curl -s ${RANGE} ${CCBASE}/${l}  
	| zcat -q
      	| tr \",\" \"\n\"
	      | sed 's/url\"/& /g'
	      | sed 's/:\"/& /g'
	      | grep \"url\"
	      | grep http
	      | awk '{print \$3}'
	      | sed s/[\\\",]//g
	      | awk -F/ '{print \$3}'
	      | awk '{for(i=1;i<=NF;i++) result[\$i]++}END{for(k in result) print k,result[k]}'" &
        endinvoc=`date +%s%N`
    done < ${TMP_DIR}/index-wat | awk '{result[$1]+=$2} END {for(k in result) print k,result[k]}' > domainstats 
    beforebarrier=`date +%s%N`
    wait
    end=`date +%s%N`
    echo Execution time was `expr $end - $start` nanoseconds
    echo Barrier time was `expr $end - $beforebarrier` nanoseconds
    echo Invocation time was `expr $endinvoc - $startinvoc` nanoseconds
    # Merge all: map -n <name> mergeAll <filename> -1 map<domainname,number> -2 <function(sum,multiply,divide)>
    sshell "map -n mapdomains size"
    #LAMBDA=$(($(wc -l domainstats | awk '{print $1}')+1))
    echo "barrier ID: $BARRIER"
    echo "lambda: $LAMBDA"
    echo "Before Merge All"
    count=0
    map -n mapdomains mergeAll $(cat domainstats | awk '{s=s" -1 "$1"="$2}END{print s}') -2 sum 
    echo "After MergeAll: mapdomains size: "
    map -n mapdomains size
    #map -n mapdomains print
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

domaincount_mergeall_2ndstage(){
    map -n mapdomains clear
    map -n mapdomains size
    map -n mapdomains mergeAll $(cat domainstats | awk '{s=s" -1 "$1"="$2}END{print s}') -2 sum 
    map -n mapdomains size
    map -n mapdomains print > domainstatsmerged
}

## 7 - compute the popularity of each domain (stateful)

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

## 8 - terasort: sort key,value dataset by key (stateless)

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
#count_ips_local
#count_ips_basic
#count_ips_2
#domaincount
#domaincount_mergeall
#domaincount_stateful_mergeall
#domaincount_wo_compute
#sshell_echo
domaincount_breakdown
#domaincount_mergeall_2ndstage

