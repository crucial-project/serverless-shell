#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${DIR}/config.sh

CCBASE="https://commoncrawl.s3.amazonaws.com"
CCMAIN="CC-MAIN-2019-43" # oct. 2019
INPUT=3
RANGE="-r 0-1000"
curl -s ${CCBASE}/crawl-data/${CCMAIN}/warc.paths.gz \
    | zcat | head -n ${INPUT} > ${TMP_DIR}/index

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
    cat ${TMP_DIR}/index | parallel -I,, --env sshell "sshell --async \"map -n ips mergeAll \\\$(curl -s ${CCBASE}/,, | zcat | tr '[:space:]' '[\n*]' | grep -oE \\\"\\\b([0-9]{1,3}\\\.){3}[0-9]{1,3}\\\b\\\" | sort | uniq -c | sort -bnr | awk '{s=s\\\" -1 \\\"\\\$2\\\"=\\\"\\\$1}END{print s}') -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await \""
    sshell barrier -n ${BARRIER} -p ${LAMBDA} await
    sshell "map -n ips size"
}

average