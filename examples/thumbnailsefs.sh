#!/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TMP_DIR=/tmp/$(whoami)

CCBASE="http://commoncrawl.s3.amazonaws.com"
CCMAIN="CC-MAIN-2019-43" # oct. 2019
INPUT=24000
RANGE="-r 0-10000000"
NBLAMBDAS=100
NBRUNS=4

curl -s ${CCBASE}/crawl-data/${CCMAIN}/warc.paths.gz \
    | zcat | head -n ${INPUT} > ${TMP_DIR}/index
curl -s ${CCBASE}/crawl-data/${CCMAIN}/wat.paths.gz \
    | zcat | head -n ${INPUT} > ${TMP_DIR}/index-wat
### 1 - average content size (stateless)

THUMBNAILSEC2PATH=/home/ec2-user/efs/thumbnails
THUMBNAILSLAMBDAPATH=/mnt/efsimttsp/thumbnails
THUMBNAILSPATH=/mnt/efsimttsp/thumbnails

#CHUNKSZ=400
NBLAMBDAS=100

cleanup()
{
  rm -f *.out
}

testsync()
{

  ls $THUMBNAILSEC2PATH > thumbnails.out
  cat thumbnails.out 

  cat thumbnails.out | parallel -j100 -I,, --env sshell "sshell \" echo BEGIN SYNC LAMBDA ; echo END SYNC LAMBDA \""

  #cat $filename | parallel -I,, "sshell --async \" echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\\\$(date +%s%N) ; cd /tmp ; rm -f THUMB* ; rm -f *.png ; cd .. ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \\\$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/,, /tmp ; clock4=\\\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; ls /tmp | wc -l ; magick convert /tmp/\\\$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 /tmp/THUMB\\\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\\\$(date +%s%N) ; cp /tmp/THUMB\\\$FILEINDEX $THUMBNAILSLAMBDAPATH ; cd /tmp ;  rm -rf /tmp/THUMB* ; rm -rf /tmp/pic* ; cd .. ; clock6=\\\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdownload=\\\$(expr \\\$clock4 - \\\$clock3) ; durationconvert=\\\$(expr \\\$clock5 - \\\$clock4) ; durationupload=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationdownload = \\\$durationdownload ; echo durationconvert = \\\$durationconvert ; echo durationupload = \\\$durationupload ; echo ========== ; echo END ; echo ========== ; barrier -n ${BARRIERLOC} -p ${LAMBDAL} await \"" 


}

# curl -s ${CCBASE}/crawl-data/${CCMAIN}/wet.paths.gz | zcat | head -n ${INPUT} > ${TMP_DIR}/index
count_ips(){
    echo count_ips before declaring barrier
    #LAMBDA=$(($(wc -l ${TMP_DIR}/index | awk '{print $1}')+1))
    LAMBDA=$(($(echo ${NBLAMBDAS} | awk '{print $1}')+1))
    BARRIER=$(uuid)
    echo count_ips after declaring barrier
    sshell "map -n ips clear"
    sshell "map -n ips size"
    echo after clearing map ips
    head -n ${NBLAMBDAS} ${TMP_DIR}/index | parallel -I,, "sshell --async \"map -n ips mergeAll \\\$(curl -s ${RANGE} ${CCBASE}/,, | 2>/dev/null zcat | tr '[:space:]' '[\n*]' | grep -oE \\\"\\\b([0-9]{1,3}\\\.){3}[0-9]{1,3}\\\b\\\" | sort | uniq -c | sort -bnr | awk '{s=s\\\" -1 \\\"\\\$2\\\"=\\\"\\\$1}END{print s}') -2 sum; barrier -n ${BARRIER} -p ${LAMBDA} await \""
    echo before barrier
    sshell barrier -n ${BARRIER} -p ${LAMBDA} await
    echo after barrier
    sshell "map -n ips size"
}

testasync()
{

  ls $THUMBNAILSEC2PATH > thumbnails.out
  cat thumbnails.out 

  #LAMBDA=$(($(wc -l thumbnails.out | awk '{print $1}')+1))
  #LAMBDA=100
  LAMBDA=$(($(echo ${NBLAMBDAS} | awk '{print $1}')+1))
  BARRIER=$(uuid)
  
  echo Call async sshell
  head -n ${NBLAMBDAS} thumbnails.out | parallel -I,, "sshell --async \" echo BEGIN ASYNC LAMBDA ; echo END ASYNC LAMBDA ; barrier -n ${BARRIER} -p ${LAMBDA} await \""

  #cat $filename | parallel -I,, "sshell --async \" echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\\\$(date +%s%N) ; cd /tmp ; rm -f THUMB* ; rm -f *.png ; cd .. ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \\\$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/,, /tmp ; clock4=\\\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; ls /tmp | wc -l ; magick convert /tmp/\\\$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 /tmp/THUMB\\\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\\\$(date +%s%N) ; cp /tmp/THUMB\\\$FILEINDEX $THUMBNAILSLAMBDAPATH ; cd /tmp ;  rm -rf /tmp/THUMB* ; rm -rf /tmp/pic* ; cd .. ; clock6=\\\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdownload=\\\$(expr \\\$clock4 - \\\$clock3) ; durationconvert=\\\$(expr \\\$clock5 - \\\$clock4) ; durationupload=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationdownload = \\\$durationdownload ; echo durationconvert = \\\$durationconvert ; echo durationupload = \\\$durationupload ; echo ========== ; echo END ; echo ========== ; barrier -n ${BARRIERLOC} -p ${LAMBDAL} await \"" 

  echo before barrier
  sshell barrier -n ${BARRIER} -p ${LAMBDA} await
  echo after barrier

}

runthumbnails()
{

	echo "Run thumbnails benchmark - EFS repository - synchronous version : "

	rm -f $THUMBNAILSEC2PATH/THUMB*

	#ls $THUMBNAILSEC2PATH | head -20 > thumbnailssubset.out

	echo "Number of elements in EFS thumbnails repository before operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	ls $THUMBNAILSEC2PATH > thumbnails.out

	cat thumbnails.out 

	sshell "echo Number of elements in /tmp before operation: "
	sshell "ls /tmp/ | wc -l"
	sshell "ls /tmp/"

	echo ""
	echo ""
	echo START PROCESSING
        sleep 2

	NBJOBS=$1

	clock1=`date +%s`

	cat thumbnails.out | parallel -j$NBJOBS -I,, --env sshell "sshell \" echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\\\$(date +%s%N) ; cd /tmp ; rm -f THUMB* ; rm -f *.png ; cd .. ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \\\$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/,, /tmp ; clock4=\\\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; ls /tmp | wc -l ; magick convert /tmp/\\\$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 /tmp/THUMB\\\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\\\$(date +%s%N) ; cp /tmp/THUMB\\\$FILEINDEX $THUMBNAILSLAMBDAPATH ; cd /tmp ;  rm -rf /tmp/THUMB* ; rm -rf /tmp/pic* ; cd .. ; clock6=\\\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdownload=\\\$(expr \\\$clock4 - \\\$clock3) ; durationconvert=\\\$(expr \\\$clock5 - \\\$clock4) ; durationupload=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationdownload = \\\$durationdownload ; echo durationconvert = \\\$durationconvert ; echo durationupload = \\\$durationupload ; echo ========== ; echo END ; echo ========== \"" 

	clock2=`date +%s`

	durationthumbnails=`expr $clock2 - $clock1`

	echo ""
	echo ""
	echo ""
	echo DURATION THUMBNAILS : $durationthumbnails seconds
	echo durationoverall = $durationthumbnails 


	echo "Check EFS thumbnails repository"


	echo "Number of elements in EFS thumbnails repository after operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	#ls $THUMBNAILSEC2PATH

	echo Check number of original pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep -v THUMB | wc -l
	echo Check number of thumbnail pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep THUMB | wc -l

	echo "CHECK AWS LAMBDA /tmp"
	sshell "ls -alsth /tmp"
	#sshell "rm -rf /tmp/*"
}

runthumbnailslocal()
{

	echo "Run thumbnails benchmark - EFS repository - synchronous and local version : "

	rm -f $THUMBNAILSEC2PATH/THUMB*

	#ls $THUMBNAILSEC2PATH | head -20 > thumbnailssubset.out

	echo "Number of elements in EFS thumbnails repository before operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	ls $THUMBNAILSEC2PATH > thumbnails.out

	cat thumbnails.out 

	echo ""
	echo START PROCESSING
        sleep 2

	NBJOBS=$1

	clock1=`date +%s`

	cat thumbnails.out | parallel -j$NBJOBS -I,, " echo ========== ; echo BEGIN LOCAL; echo ========== ; clock3=\$(date +%s%N) ; rm -f THUMB* ; rm -f *.png ; echo element: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \$FILEINDEX ; cp $THUMBNAILSEC2PATH/,, . ; clock4=\$(date +%s%N) ; echo BEFORE MAGICK : ls . | wc -l ; magick convert \$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 THUMB\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\$(date +%s%N) ; cp THUMB\$FILEINDEX $THUMBNAILSEC2PATH ;  rm -rf /tmp/THUMB* ; rm -rf pic* ; clock6=\$(date +%s%N) ; echo Number of elements in .: ; ls . | wc -l ; echo Content of thumbnails AWS EFS repository: ; durationdownload=\$(expr \$clock4 - \$clock3) ; durationconvert=\$(expr \$clock5 - \$clock4) ; durationupload=\$(expr \$clock6 - \$clock5) ; echo durationdownload = \$durationdownload ; echo durationconvert = \$durationconvert ; echo durationupload = \$durationupload ; echo ========== ; echo END ; echo ========== " 

	clock2=`date +%s`

	durationthumbnails=`expr $clock2 - $clock1`

	echo ""
	echo ""
	echo ""
	echo DURATION THUMBNAILS : $durationthumbnails seconds
	echo durationoverall = $durationthumbnails 

	echo "Check EFS thumbnails repository"


	echo "Number of elements in EFS thumbnails repository after operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	#ls $THUMBNAILSEC2PATH

	echo Check number of original pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep -v THUMB | wc -l
	echo Check number of thumbnail pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep THUMB | wc -l

}


runparallelnoop()
{

	ls $THUMBNAILSEC2PATH > thumbnails.out

	NBJOBS=$1

	clock1=`date +%s`
	for iter in $(seq 1 $NBRUNS)
        do
	  echo run $iter
	  cat thumbnails.out | parallel -j$NBJOBS  "clock3=\$(date +%s%N) ; echo ,, > /dev/null ; sleep 10 ; clock4=\$(date +%s%N) ; durationsleep=\$(expr \$clock4 - \$clock3) ; echo durationsleep = \$durationsleep"
	done
	clock2=`date +%s`
	durationaccparallel=`expr $clock2 - $clock1`

        #durationavgparallel=$((durationaccparallel / ${NBRUNS}))
	echo ""
	echo ""
	echo ""
	echo durationoverall = $durationaccparallel

}

runthumbnailsnoop()
{

	echo ""
	echo "Run Thumbnails w/o any operation (NO 0P) "

	rm -f $THUMBNAILSEC2PATH/THUMBNAIL*

	#ls $THUMBNAILSEC2PATH | head -20 > thumbnailssubset.out

	echo "Number of elements in EFS thumbnails repository before operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	ls $THUMBNAILSEC2PATH > thumbnails.out

	echo ""
	echo ""
	echo START PROCESSING

	NBJOBS=$1

	clock1=`date +%s`
	for iter in $(seq 1 $NBRUNS)
        do
	  echo run $iter
	  cat thumbnails.out | parallel -j$NBJOBS -I,, --env sshell "clock3=\$(date +%s%N) ; sshell \" clock4=\\\$(date +%s%N) ; echo ,, > /dev/null ; sleep 10 ; clock5=\\\$(date +%s%N) ; durationinvokesshell=\\\$(expr \\\$clock4 - \$clock3) ; durationsleep=\\\$(expr \\\$clock5 - \\\$clock4) ; echo durationinvokesshell = \\\$durationinvokesshell ; echo durationsleep = \\\$durationsleep \""
        done
	clock2=`date +%s`

	durationthumbnails=`expr $clock2 - $clock1`

	echo ""
	echo ""
	echo ""
	echo DURATION THUMBNAILS : $durationthumbnails seconds
	echo durationoverall = $durationthumbnails

	echo "Check EFS thumbnails repository"

	echo "Number of elements in EFS thumbnails repository after operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	#ls $THUMBNAILSEC2PATH

	echo Check number of original pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep -v THUMB | wc -l
	echo Check number of thumbnail pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep THUMB | wc -l

	echo "CHECK AWS LAMBDA /tmp"
	sshell "ls -alsth /tmp"
	#sshell "rm -rf /tmp/*"
}

runthumbnailsasyncck()
{
	echo "Run thumbnails async benchmark - EFS repository - asynchronous version : "
        echo $1 chunk size

	rm -f $THUMBNAILSEC2PATH/THUMB*

	#ls $THUMBNAILSEC2PATH | head -20 > thumbnailssubset.out
       	echo "Number of elements in EFS thumbnails repository before operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	ls $THUMBNAILSEC2PATH > thumbnails.out

	CKSIZE=$1

	clock1=`date +%s`

	LAMBDAGLOB=$(($(wc -l thumbnails.out | awk '{print $1}')+1))
	#LAMBDA=600
        #LAMBDA=$(($(echo ${NBLAMBDAS} | awk '{print $1}')+1))
        BARRIERGLOB=$(uuid)
        rm -rf ckthumbnails*
        split -l $CKSIZE -d thumbnails.out ckthumbnails
        iter=0
	for filename in ckthumbnails*
	do
	  iter=$((iter+1))
	  clockckbegin=`date +%s`
	  LAMBDALOC=$(($(wc -l $filename | awk '{print $1}')+1))
          BARRIERLOC=$(uuid)
	  echo Iterate $iter, BARRIERLOC=$BARRIERLOC, LAMBDALOC=$LAMBDALOC
	  cat $filename | parallel -I,, "sshell --async \" echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\\\$(date +%s%N) ; cd /tmp ; rm -f THUMB* ; rm -f *.png ; cd .. ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \\\$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/,, /tmp ; clock4=\\\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; ls /tmp | wc -l ; magick convert /tmp/\\\$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 /tmp/THUMB\\\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\\\$(date +%s%N) ; cp /tmp/THUMB\\\$FILEINDEX $THUMBNAILSLAMBDAPATH ; cd /tmp ;  rm -rf /tmp/THUMB* ; rm -rf /tmp/pic* ; cd .. ; clock6=\\\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdownload=\\\$(expr \\\$clock4 - \\\$clock3) ; durationconvert=\\\$(expr \\\$clock5 - \\\$clock4) ; durationupload=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationdownload = \\\$durationdownload ; echo durationconvert = \\\$durationconvert ; echo durationupload = \\\$durationupload ; echo ========== ; echo END ; echo ========== ; barrier -n ${BARRIERLOC} -p ${LAMBDALOC} await \"" 

	  echo Iterate $iter, pass local barrier ...
	  sshell barrier -n ${BARRIERLOC} -p ${LAMBDALOC} await
	  echo Iterate $iter, local barrier PASSED
	  clockckend=`date +%s`
	  durationthumbck=`expr $clockckend - $clockckbegin`
	  echo durationthumbck_$iter = $durationthumbck
	  #arraycktime[$iter]=durationthumbck
	done

	#echo Iterate $iter, pass global barrier, BARRIERGLOB=$BARRIERGLOB, LAMBDAGLOB=$LAMBDAGLOB ...
	#sshell barrier -n ${BARRIERGLOB} -p ${LAMBDAGLOB} await
	#echo Iterate $iter, global barrier PASSED

	clock2=`date +%s`

	durationthumbnails=`expr $clock2 - $clock1`

	echo ""
	echo ""
	echo ""
	echo DURATION THUMBNAILS : $durationthumbnails seconds
	echo durationoverall = $durationthumbnails 

	echo "Check EFS thumbnails repository"

	echo "Number of elements in EFS thumbnails repository after operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	#ls $THUMBNAILSEC2PATH

	echo Check number of original pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep -v THUMB | wc -l
	echo Check number of thumbnail pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep THUMB | wc -l

}


runthumbnailsasync()
{

	echo "Run thumbnails async benchmark - EFS repository - asynchronous version : "
        echo $1 parallel jobs

	rm -f $THUMBNAILSEC2PATH/THUMB*

	#ls $THUMBNAILSEC2PATH | head -20 > thumbnailssubset.out
       	echo "Number of elements in EFS thumbnails repository before operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	ls $THUMBNAILSEC2PATH > thumbnails.out

	LAMBDA=$(($(wc -l thumbnails.out | awk '{print $1}')+1))
	#LAMBDA=600
        #LAMBDA=$(($(echo ${NBLAMBDAS} | awk '{print $1}')+1))
        BARRIER=$(uuid)

	#sshell "rm -rf /tmp/pic*"
	#sshell "rm -rf /tmp/THUMB*"
	sshell "echo Number of elements in /tmp before operation: "
	sshell "ls /tmp/ | wc -l"

	echo ""
	echo ""
	echo START PROCESSING
	echo LAMBDA = ${LAMBDA}
        sleep 2

	NBJOBS=$1

	clock1=`date +%s`

	#while read l
	#do
	#  sshell --async "echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\$(date +%s%N) ; cd /tmp ; rm -f THUMB* ; rm -f *.png ; cd .. ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/${l} /tmp ; clock4=\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; ls /tmp | wc -l ; magick convert /tmp/\$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 /tmp/THUMB\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\$(date +%s%N) ; cp /tmp/THUMB\$FILEINDEX $THUMBNAILSLAMBDAPATH ; cd /tmp ;  rm -rf /tmp/THUMB* ; rm -rf /tmp/pic* ; cd .. ; clock6=\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdownload=\$(expr \$clock4 - \$clock3) ; durationconvert=\$(expr \$clock5 - \$clock4) ; durationupload=\$(expr \$clock6 - \$clock5) ; echo durationdownload = \$durationdownload ; echo durationconvert = \$durationconvert ; echo durationupload = \$durationupload ; echo ========== ; echo END ; echo ========== " 
	#done < thumbnails.out

	cat thumbnails.out | parallel -j100 -I,, "sshell --async \" echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\\\$(date +%s%N) ; cd /tmp ; rm -f THUMB* ; rm -f *.png ; cd .. ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \\\$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/,, /tmp ; clock4=\\\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; ls /tmp | wc -l ; magick convert /tmp/\\\$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 /tmp/THUMB\\\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\\\$(date +%s%N) ; cp /tmp/THUMB\\\$FILEINDEX $THUMBNAILSLAMBDAPATH ; cd /tmp ;  rm -rf /tmp/THUMB* ; rm -rf /tmp/pic* ; cd .. ; clock6=\\\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdownload=\\\$(expr \\\$clock4 - \\\$clock3) ; durationconvert=\\\$(expr \\\$clock5 - \\\$clock4) ; durationupload=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationdownload = \\\$durationdownload ; echo durationconvert = \\\$durationconvert ; echo durationupload = \\\$durationupload ; echo ========== ; echo END ; echo ========== ; barrier -n ${BARRIER} -p ${LAMBDA} await \"" 
	#head -n ${LAMBDA} thumbnails.out | parallel -I,, "sshell --async \" echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\\\$(date +%s%N) ; cd /tmp ; rm -f THUMB* ; rm -f *.png ; cd .. ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \\\$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/,, /tmp ; clock4=\\\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; ls /tmp | wc -l ; magick convert /tmp/\\\$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 /tmp/THUMB\\\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\\\$(date +%s%N) ; cp /tmp/THUMB\\\$FILEINDEX $THUMBNAILSLAMBDAPATH ; cd /tmp ;  rm -rf /tmp/THUMB* ; rm -rf /tmp/pic* ; cd .. ; clock6=\\\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdownload=\\\$(expr \\\$clock4 - \\\$clock3) ; durationconvert=\\\$(expr \\\$clock5 - \\\$clock4) ; durationupload=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationdownload = \\\$durationdownload ; echo durationconvert = \\\$durationconvert ; echo durationupload = \\\$durationupload ; echo ========== ; echo END ; echo ========== ; barrier -n ${BARRIER} -p ${LAMBDA} await \"" 
        
	sshell barrier -n ${BARRIER} -p ${LAMBDA} await

	clock2=`date +%s`

	durationthumbnails=`expr $clock2 - $clock1`

	echo ""
	echo ""
	echo ""
	echo DURATION THUMBNAILS : $durationthumbnails seconds
	echo durationoverall = $durationthumbnails 

	echo "Check EFS thumbnails repository"

	echo "Number of elements in EFS thumbnails repository after operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	#ls $THUMBNAILSEC2PATH

	echo Check number of original pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep -v THUMB | wc -l
	echo Check number of thumbnail pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep THUMB | wc -l

	echo "CHECK AWS LAMBDA /tmp"
	sshell "ls -alsth /tmp"
	#sshell "rm -rf /tmp/*"
}



runthumbnailsasync2()
{

	echo "Run thumbnails async benchmark - EFS repository - asynchronous version : "
        echo $1 parallel jobs

	rm -f $THUMBNAILSEC2PATH/THUMB*

	#ls $THUMBNAILSEC2PATH | head -20 > thumbnailssubset.out

	echo "Number of elements in EFS thumbnails repository before operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	ls $THUMBNAILSEC2PATH > thumbnails.out

	#sshell "rm -rf /tmp/pic*"
	#sshell "rm -rf /tmp/THUMB*"
	sshell "echo Number of elements in /tmp before operation: "
	sshell "ls /tmp/ | wc -l"

	echo ""
	echo ""
	echo START PROCESSING
        sleep 2

	NBJOBS=$1

	clock1=`date +%s`

	cat thumbnails.out | parallel -j$NBJOBS -I,, "sshell --async \" echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\\\$(date +%s%N) ; cd /tmp ; rm -f THUMB* ; rm -f *.png ; cd .. ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \\\$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/,, /tmp ; clock4=\\\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; ls /tmp | wc -l ; magick convert /tmp/\\\$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 /tmp/THUMB\\\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\\\$(date +%s%N) ; cp /tmp/THUMB\\\$FILEINDEX $THUMBNAILSLAMBDAPATH ; cd /tmp ;  rm -rf /tmp/THUMB* ; rm -rf /tmp/pic* ; cd .. ; clock6=\\\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdownload=\\\$(expr \\\$clock4 - \\\$clock3) ; durationconvert=\\\$(expr \\\$clock5 - \\\$clock4) ; durationupload=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationdownload = \\\$durationdownload ; echo durationconvert = \\\$durationconvert ; echo durationupload = \\\$durationupload ; echo ========== ; echo END ; echo ========== \"" 

	clock2=`date +%s`

	durationthumbnails=`expr $clock2 - $clock1`

	echo ""
	echo ""
	echo ""
	echo DURATION THUMBNAILS : $durationthumbnails seconds
	echo durationoverall = $durationthumbnails 

	echo "Check EFS thumbnails repository"

	echo "Number of elements in EFS thumbnails repository after operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	#ls $THUMBNAILSEC2PATH

	echo Check number of original pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep -v THUMB | wc -l
	echo Check number of thumbnail pictures in EFS/thumbnails directory
	ls $THUMBNAILSEC2PATH/ | grep THUMB | wc -l

	echo "CHECK AWS LAMBDA /tmp"
	sshell "ls -alsth /tmp"
	#sshell "rm -rf /tmp/*"
}

#rm -rf runthumbnails.* runthumbnailsasync.* *.out
cleanup

# Run thumbnails with a range of #jobs
#njobs=(10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800)
njobs=(20 30 40 60 80 100 200 300 400 500 600 700 800)
#njobs=(40 60 80 100 200 300 400 500 600 700 800)
#cksize=(10 20 40 60 80 100 200 400 600 800)
cksize=(100 200 400 600 800)

#njobs=(90 100 200 300 400 500 600 700 800)
echo Run thumbnails with a range of #njobs

#runthumbnails 10 &> thumbnails.10.out 
#runthumbnails 10 

echo Thumbnails Sync version 
for ijob in "${njobs[@]}"
do
  echo =================================
  echo $ijob parallel jobs
  #runthumbnails $ijob 
  #runthumbnails $i > runthumbnails.$i.njobs.out
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i 
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i > thumbnails.perfbreakdown.$i.njobs.out
done
echo ""
echo =================================
echo =================================
echo ""
echo Thumbnails local version 
for ijob in "${njobs[@]}"
do
  echo =================================
  echo $ijob parallel jobs
  runthumbnailslocal $ijob 
  #runthumbnailslocal $ijob > runthumbnailslocal.$ijob.njobs.out
  #bash examples/perfbreakdown.sh runthumbnailslocal.$ijob.njobs.out $ijob 
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i > thumbnails.perfbreakdown.$i.njobs.out
done
echo ""
echo =================================
echo =================================
echo ""
echo Parallel NO OP version 
for ijob in "${njobs[@]}"
do
  echo =================================
  echo $ijob parallel jobs
  #runparallelnoop $ijob > runparallelnoop.$ijob.njobs.out
  #bash examples/perfbreakdown.sh runparallelnoop.$ijob.njobs.out $ijob $NBRUNS
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i > thumbnails.perfbreakdown.$i.njobs.out
done
echo ""
echo =================================
echo =================================
echo ""
echo Thumbnails NO OP version 
for ijob in "${njobs[@]}"
do
  echo =================================
  echo $ijob parallel jobs
  #runthumbnailsnoop $ijob 
  #runthumbnailsnoop $ijob > runthumbnailsnoop.$ijob.njobs.out
  #bash examples/perfbreakdown.sh runthumbnailsnoop.$ijob.njobs.out $ijob $NBRUNS
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i > thumbnails.perfbreakdown.$i.njobs.out
done
echo ""
echo =================================
echo =================================
echo ""
echo Async version
for ijob in "${njobs[@]}"
do
  echo $ijob parallel jobs
  #runthumbnailsasync $ijob 
  #runthumbnailsasync $ijob > runthumbnailsasync.$ijob.njobs.out
  #bash examples/perfbreakdown.sh runthumbnailsasync.njobs.out $ijob 
  #bash examples/bugtracker.sh runthumbnailsasync.$ijob.njobs.out $ijob
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i > thumbnails.perfbreakdown.$i.njobs.out
done
echo ""
echo =================================
echo =================================
echo ""
echo Async w/ chunks version 
#ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
numelmtsinput=$(ls $THUMBNAILSEC2PATH | wc -l)
for icksize in "${cksize[@]}"
do
  echo $icksize chunk size
  #runthumbnailsasyncck $icksize
  #runthumbnailsasyncck $icksize > runthumbnailsasyncck.$icksize.cksize.out
  #bash examples/perfbreakdown.sh runthumbnails.$icksize.cksize.out $numelmtsinput $icksize > thumbnails.perfbreakdown.$icksize.cksize.out
done

#testsync
#testasync
#count_ips
