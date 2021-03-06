#!/bin/bash -x

THUMBNAILSEC2PATH=/home/ec2-user/efs/thumbnails
THUMBNAILSLAMBDAPATH=/mnt/efsimttsp/thumbnails
THUMBNAILSPATH=/mnt/efsimttsp/thumbnails



runthumbnails()
{

	echo "Display AWS S3 THUMBNAILS content : "

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

	  
	sleep 2
	echo ""
	echo ""
	echo START PROCESSING

	NBJOBS=$1

	clock1=`date +%s`

	cat thumbnails.out | parallel -j$NBJOBS -I,, --env sshell "sshell \" echo ========== ; echo BEGIN LAMBDA; echo ========== ; clock3=\\\$(date +%s%N) ; rm -rf /tmp/pic* ; rm -rf /tmp/THUMB* ; echo AFTER CLEARING /tmp : ls /tmp ; echo lambda: ,, ; FILEINDEX=,, ; echo FILEINDEX: ; echo \\\$FILEINDEX ; cp $THUMBNAILSLAMBDAPATH/,, /tmp ; clock4=\\\$(date +%s%N) ; echo BEFORE MAGICK : ls /tmp ; magick convert -define png:size=300x100 /tmp/\\\$FILEINDEX -auto-orient -thumbnail 180x110 -unsharp 0x.5 /tmp/THUMBNAIL\\\$FILEINDEX ; echo AFTER MAGICK : ; clock5=\\\$(date +%s%N) ; cp /tmp/THUMBNAIL\\\$FILEINDEX $THUMBNAILSLAMBDAPATH ; rm -rf /tmp/pic* ; rm -rf /tmp/THUMB* ; clock6=\\\$(date +%s%N) ; echo Number of elements in /tmp: ; ls /tmp/ | wc -l ;  echo Content of thumbnails AWS EFS repository: ; durationdowload=\\\$(expr \\\$clock4 - \\\$clock3) ; durationconvert=\\\$(expr \\\$clock5 - \\\$clock4) ; durationupload=\\\$(expr \\\$clock6 - \\\$clock5) ; echo durationdownload = \\\$durationdownload ; echo durationconvert = \\\$durationconvert ; echo durationupload = \\\$durationupload ; echo ========== ; echo END ; echo ========== \"" 

	clock2=`date +%s`

	durationthumbnails=`expr $clock2 - $clock1`

	echo ""
	echo ""
	echo ""
	echo DURATION THUMBNAILS : $durationthumbnails seconds


	sleep 2
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

# Run thumbnails with a range of #jobs
njobs=(10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800)
echo Run thumbnails with a range of #njobs

for i in "${njobs[@]}"
do
  echo $i
  runthumbnails $i
done

#runthumbnails 10



