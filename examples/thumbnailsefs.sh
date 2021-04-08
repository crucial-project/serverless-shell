#!/bin/bash -x

THUMBNAILSEC2PATH=/home/ec2-user/efs/thumbnails
THUMBNAILSLAMBDAPATH=/mnt/efsimttsp/thumbnails
THUMBNAILSPATH=/mnt/efsimttsp/thumbnails

CHUNKSZ=400

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

runthumbnailsnoop()
{

	echo "Run Thumbnails w/o any operation (NO UP) "

	rm -f $THUMBNAILSEC2PATH/THUMBNAIL*

	#ls $THUMBNAILSEC2PATH | head -20 > thumbnailssubset.out

	echo "Number of elements in EFS thumbnails repository before operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	ls $THUMBNAILSEC2PATH > thumbnails.out

	sshell "rm -rf /tmp/pic*"
	sshell "rm -rf /tmp/THUMB*"
	sshell "echo Number of elements in /tmp before operation: "
	sshell "ls /tmp/ | wc -l"

	echo ""
	echo ""
	echo START PROCESSING

	NBJOBS=$1

	clock1=`date +%s`

	cat thumbnails.out | parallel -j$NBJOBS -I,, --env sshell "sshell \" true \""
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
        echo $1 parallel jobs

	rm -f $THUMBNAILSEC2PATH/THUMB*

	#ls $THUMBNAILSEC2PATH | head -20 > thumbnailssubset.out
       	echo "Number of elements in EFS thumbnails repository before operation: "
	ls $THUMBNAILSEC2PATH | wc -l > numelementsthumbnails.out
	cat numelementsthumbnails.out

	ls $THUMBNAILSEC2PATH > thumbnails.out

	clock1=`date +%s`

	LAMBDAGLOB=$(($(wc -l thumbnails.out | awk '{print $1}')+1))
	#LAMBDA=600
        #LAMBDA=$(($(echo ${NBLAMBDAS} | awk '{print $1}')+1))
        BARRIERGLOB=$(uuid)

        split -l $CHUNKSZ -d thumbnails.out ckthumbnails
        iter=0
	for filename in ckthumbnails*
	do
	  iter=$((iter+1))
	  LAMBDALOC=$(($(wc -l $filename | awk '{print $1}')+1))
          BARRIERLOC=$(uuid)
	  cat $filename | parallel -j100 -I,, "sshell --async \" echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\\\$(date +%s%N) ; cd /tmp ; rm -f THUMB* ; rm -f *.png ; cd .. ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \\\$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/,, /tmp ; clock4=\\\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; ls /tmp | wc -l ; magick convert /tmp/\\\$FILEINDEX -thumbnail 70x70^ -unsharp 0x.4 /tmp/THUMB\\\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\\\$(date +%s%N) ; cp /tmp/THUMB\\\$FILEINDEX $THUMBNAILSLAMBDAPATH ; cd /tmp ;  rm -rf /tmp/THUMB* ; rm -rf /tmp/pic* ; cd .. ; clock6=\\\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdownload=\\\$(expr \\\$clock4 - \\\$clock3) ; durationconvert=\\\$(expr \\\$clock5 - \\\$clock4) ; durationupload=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationdownload = \\\$durationdownload ; echo durationconvert = \\\$durationconvert ; echo durationupload = \\\$durationupload ; echo ========== ; echo END ; echo ========== ; barrier -n ${BARRIERLOC} -p ${LAMBDALOC} await \"" 

	  sshell barrier -n ${BARRIERLOC} -p ${LAMBDALOC} await
	done

	sshell barrier -n ${BARRIERGLOB} -p ${LAMBDAGLOB} await

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

rm -rf runthumbnails.* runthumbnailsasync.* *.out

# Run thumbnails with a range of #jobs
njobs=(10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800)
#njobs=(90 100 200 300 400 500 600 700 800)
echo Run thumbnails with a range of #njobs

#runthumbnails 10 &> thumbnails.10.out 
#runthumbnails 10 

echo Sync version 
for ijob in "${njobs[@]}"
do
  echo =================================
  echo $ijob jobs
  #runthumbnails $ijob 
  #runthumbnails $i > runthumbnails.$i.njobs.out
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i 
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i > thumbnails.perfbreakdown.$i.njobs.out
done

echo Async version
for ijob in "${njobs[@]}"
do
  echo $ijob jobs
  #runthumbnailsasync $ijob 
  #runthumbnailsasync $ijob > runthumbnailsasync.$ijob.njobs.out
  #bash examples/perfbreakdown.sh runthumbnailsasync.njobs.out $ijob 
  #bash examples/bugtracker.sh runthumbnailsasync.$ijob.njobs.out $ijob
  #bash examples/perfbreakdown.sh runthumbnails.$i.njobs.out $i > thumbnails.perfbreakdown.$i.njobs.out
done

runthumbnailsasyncck

