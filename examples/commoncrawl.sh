#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TMP_DIR=/tmp/$(whoami)

CCBASE="http://commoncrawl.s3.amazonaws.com"
CCMAIN="CC-MAIN-2019-43" # oct. 2019
INPUT=60000
RANGE="-r 0-10000000"

curl -s ${CCBASE}/crawl-data/${CCMAIN}/warc.paths.gz \
    | zcat | head -n ${INPUT} > ${TMP_DIR}/index
curl -s ${CCBASE}/crawl-data/${CCMAIN}/wat.paths.gz \
    | zcat | head -n ${INPUT} > ${TMP_DIR}/index-wat
### 1 - average content size (stateless)

average(){
    while read l; do
	sshell "curl -s ${RANGE} ${CCBASE}/${l} | 2>/dev/null zcat -q | grep ^Content-Length " &
    done < ${TMP_DIR}/index | awk '{ sum += $2 } END { if (NR > 0) print int(sum / NR) }'
}
    
### 2 - average content size (stateful)

average_stateful(){
    sshell "counter -n average reset"
    while read l; do
	sshell "counter -n average increment -i \$(curl -s ${RANGE} ${CCBASE}/${l} | 2>/dev/null zcat | grep ^Content-Length | awk '{ sum += \$2 } END { if (NR > 0) print int(sum / NR) }')" 1> /dev/null &
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
    seq 1 1 $((LAMBDA-1)) | parallel -n0 sshell --async barrier -n ${BARRIER} -p ${LAMBDA}  await
    sshell barrier -n ${BARRIER} -p ${LAMBDA} await
}

### 4 - count IPs
# FIXME grep too old w. runtime=java8

# curl -s ${CCBASE}/crawl-data/${CCMAIN}/wet.paths.gz | zcat | head -n ${INPUT} > ${TMP_DIR}/index
count_ips(){
    LAMBDA=$(($(wc -l ${TMP_DIR}/index | awk '{print $1}')+1))
    BARRIER=$(uuid)
    sshell "map -n ips clear"
    cat ${TMP_DIR}/index | parallel -I,, "sshell --async \"map -n ips mergeAll \\\$(curl -s ${RANGE} ${CCBASE}/,, | 2>/dev/null zcat | tr '[:space:]' '[\n*]' | grep -oE \\\"\\\b([0-9]{1,3}\\\.){3}[0-9]{1,3}\\\b\\\" | sort | uniq -c | sort -bnr | awk '{s=s\\\" -1 \\\"\\\$2\\\"=\\\"\\\$1}END{print s}') -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await \""
    sshell barrier -n ${BARRIER} -p ${LAMBDA} await
    sshell "map -n ips size"
}

## 5 - compute the popularity of each domain

domaincount(){
    while read l; do
	sshell "curl -s ${RANGE} ${CCBASE}/${l}
      	| 2>/dev/null zcat -q | tr \",\" \"\n\"
	| sed 's/url\"/& /g' 
	| sed 's/:\"/& /g' 
	| grep \"url\" | grep http | awk '{print \$3}' | sed s/[\\\",]//g | awk -F/ '{print \$3}'  | awk '{for(i=1;i<=NF;i++) result[\$i]++} END {for(k in result) print k,result[k]}' | sort -k 2 -n -r" &
    done < ${TMP_DIR}/index-wat | awk '{result[$1]+=$2} END {for(k in result) print k,result[k]}' | sort -k 2 -n -r
    wait
}

buildperfbreakdownsummary() {

 durationnanoioacc=0
 durationnanocomputeacc=0
 durationnanosyncacc=0

 cat $1 | grep durationio > durationio.out
 cat $1 | grep durationprocess > durationprocess.out
 cat $1 | grep durationsync > durationsync.out

 #cat durationio.out
 #cat durationprocess.out

 # Read S3 IO file
 while read l; do
   measure=$(echo ${l} | awk '{print $3}')
   #echo "time io: $measure"
   durationnanoioacc=$((durationnanoioacc+$measure))
 done < durationio.out

 # Read Compute file
 while read l; do
   measure=$(echo ${l} | awk '{print $3}')
   #echo "time compute: $measure"
   durationnanocomputeacc=$((durationnanocomputeacc+$measure))
 done < durationprocess.out

 # Read Sync file
 while read l; do
   measure=$(echo ${l} | awk '{print $3}')
 #  echo "time sync: $measure"
   durationnanosyncacc=$((durationnanosyncacc+$measure))
 done < durationsync.out

 echo "duration S3 IO: $durationnanoioacc nanoseconds" 
 echo "duration Compute: $durationnanocomputeacc nanoseconds" 
 echo "duration Sync: $durationnanosyncacc nanoseconds" 

 #echo $($durationnanoioacc/1000000)
 #echo $($durationnanocomputeacc/1000000)
 #echo $($durationnanosyncacc/1000000)
 
 durationioaccsecs=$((durationnanoioacc / 1000000000)) 
 durationcomputeaccsecs=$((durationnanocomputeacc / 1000000000)) 
 durationsyncaccsecs=$((durationnanosyncacc / 1000000000)) 
 
 #durationioavg=$((durationioaccsecs / ${INPUT}))
 #durationcomputeavg=$((durationcomputeaccsecs / ${INPUT}))
 #durationsyncavg=$((durationsyncaccsecs / ${INPUT}))

 #durationioacc=$((durationnanoioacc / 1000000))
 #durationcomputeacc=$((durationnanocomputeacc / 1000000))
 #durationsyncacc=$((durationnanosyncacc / 1000000))
 
 echo "Performance Breakdown Summary"

 echo "Overall duration S3 IO: $durationioaccsecs seconds" 
 echo "Overall duration Compute: $durationcomputeaccsecs seconds" 
 echo "Overall duration Sync: $durationsyncaccsecs seconds" 

}


domaincount_parallel_stateless(){

  clock1=`date +%s`

  cat ${TMP_DIR}/index-wat | parallel -j300 -I,, --env sshell "sshell \" clock1=\\\$(date +%s%N) ; curl -s ${RANGE} ${CCBASE}/,, 
  | zcat -q > /tmp/curl.out ; clock2=\\\$(date +%s%N) ; cat /tmp/curl.out 
  | tr \\\",\\\" \\\"\n\\\" 
  | sed 's/url\\\"/& /g' 
  | sed 's/:\\\"/& /g' 
  | grep \\\"url\\\" 
  | grep http: 
  | awk '{print \\\$3}'
  | awk -F/ '{print \\\$3}' 
  | cut -f1 -d":" 
  | cut -f1 -d'\' 
  | cut -f1 -d"?"  
  | cut -f1 -d"=" 
  | cut -f1 -d"'#'" 
  | sed 's/\\\"//g'
  | awk '{for(i=1;i<=NF;i++) result[\\\$i]++}END{for(k in result) print k,result[k]}' ; clock3=\\\$(date +%s%N) ; durationio=\\\$(expr \\\$clock2 - \\\$clock1) ; durationprocess=\\\$(expr \\\$clock3 - \\\$clock2) ; echo clock1 \\\$clock1 ; echo clock2 \\\$clock2 ; echo clock3 \\\$clock3 ; echo durationio = \\\$durationio ; echo durationprocess = \\\$durationprocess \"" > domaincountbreakdown.out 

  clock2=`date +%s`
  duration=`expr $clock2 - $clock1`

  echo "duration domaincount: $duration seconds"

  wc -l domaincountbreakdown.out > domaincountbeforemergeall.out
  echo "Number of lines before mergeAll "
  cat domaincountbeforemergeall.out

  #awk '{ domain[$1] += $2 } END { for (i in domain) print i, domain[i] }' domaincountbreakdown.out > domaincountbreakdownmerged.out
  #cat domaincountbreakdownmerged.out | sort -k 2 -n -r > domaincountbreakdownmergedsorted.out
  #echo sync duration: $durationsync seconds

}

domaincount_parallel_stateful()
{
  LAMBDA=$(($(wc -l ${TMP_DIR}/index-wat | awk '{print $1}')+1))
  BARRIER=$(uuid)

  sshell treemap -n mapdomains clear
  echo "Size of DSO map mapdomains before mergeAll: "
  sshell treemap -n mapdomains size

  clock1=`date +%s`
  #cat ${TMP_DIR}/index-wat | parallel -j10 -I,, --env sshell "sshell \"curl -s ${RANGE} ${CCBASE}/,, | zcat -q > /tmp/curl.out ; cat /tmp/curl.out  | tr \",\" \"\n\" | sed 's/url\\\"/& /g' | sed 's/:\\\"/& /g' | grep \"url\" | grep http: | awk '{print \$3}' | sed s/[\\\\\",]//g | awk -F '{print \$3}' \""

  cat ${TMP_DIR}/index-wat | parallel -j400 -I,, --env sshell "sshell \" clock1=\\\$(date +%s%N) ; curl -s ${RANGE} ${CCBASE}/,, 
  | zcat -q > /tmp/curl.out ; clock2=\\\$(date +%s%N) ; cat /tmp/curl.out  
  | tr \\\",\\\" \\\"\n\\\" 
  | sed 's/url\\\"/& /g' 
  | sed 's/:\\\"/& /g' 
  | grep \\\"url\\\" 
  | grep http:  
  | awk '{print \\\$3}'
  | awk -F/ '{print \\\$3}' 
  | cut -f1 -d":" 
  | cut -f1 -d'\' 
  | cut -f1 -d"?" 
  | cut -f1 -d"=" 
  | cut -f1 -d"'#'" 
  | sed 's/\\\"//g'
  | awk '{for(i=1;i<=NF;i++) result[\\\$i]++}END{for(k in result) print k,result[k]}' > /tmp/domaincount.out ; clock3=\\\$(date +%s%N) ; treemap -n mapdomains mergeAll \\\$(cat /tmp/domaincount.out 
  | awk '{s=s\\\" -1 \\\"\\\$1\\\"=\\\"\\\$2}END{print s}') -2 sum ; clock4=\\\$(date +%s%N) ; durationio=\\\$(expr \\\$clock2 - \\\$clock1) ;  durationprocess=\\\$(expr \\\$clock3 - \\\$clock2) ; durationsync=\\\$(expr \\\$clock4 - \\\$clock3) ; echo durationio = \\\$durationio ; echo durationprocess = \\\$durationprocess ; echo durationsync = \\\$durationsync \"" > domaincountbreakdown.out

  clock2=`date +%s`
  duration1=`expr $clock2 - $clock1`

  echo "duration domaincount: $duration1 seconds"

  echo "Sort"
  sshell treemap -n mapdomains size
  sshell treemap -n mapdomains reverse -1
  clock4=`date +%s`
  sshell treemap -n mapdomains top -1 100 > map.out
  clock5=`date +%s`
  cat map.out | sed 's/{//g' > map2.out
  cat map2.out | sed 's/}//g' > map3.out
  cat map3.out | sed 's/,/\n/g' > map4.out
  cat map4.out | tr '=' ' ' > domaincountsorted.out

  cat domaincountsorted.out

  clock3=`date +%s`
  duration2=`expr $clock3 - $clock2`
  duration3=`expr $clock5 - $clock4`

  echo "duration sort: $duration2 seconds"
  echo "duration topk: $duration3 seconds"

  #awk '{ domain[$1] += $2 } END { for (i in domain) print i, domain[i] }' domaincountbreakdown.out > domaincountbreakdownmerged.out
}

test_map()
{

  sshell map -n mapdomains size
  sshell map -n mapdomains clear
  sshell map -n mapdomains size
  sshell map -n mapdomains flush

}

# average_stateful
# gathering
# average
#count_ips
#test_map
#domaincount_parallel_stateless
domaincount_parallel_stateful
buildperfbreakdownsummary "domaincountbreakdown.out"
