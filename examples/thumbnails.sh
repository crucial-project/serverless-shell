#!/bin/bash -x

THUMBNAILSBASES3="s3://amaheo/thumbnails"
THUMBNAILSBASE="http://amaheo.s3-website-us-east-1.amazonaws.com/thumbnails"

echo "Display AWS S3 THUMBNAILS content : "
#aws s3 ls $THUMBNAILSBASE/
#aws s3 ls $THUMBNAILSBASE/ | wc -l
aws s3 ls $THUMBNAILSBASES3/ > thumbnails_content.out
awk '{ print $4 }' thumbnails_content.out > thumbnails_refined_content.out

echo ""
echo ""
echo cat thumbnails content :
cat thumbnails_content.out 

echo ""
echo ""
echo cat refined thumbnails content :
cat thumbnails_refined_content.out 

clock1=`date +%s`

cat thumbnails_refined_content.out | parallel -j100 -I,, --env sshell "sshell \" rm -rf /tmp/* ; echo do pwd ; pwd ; export HOME=/var/task ; echo HOME ; echo echo \\\$HOME ; echo LD_LIBRARY_PATH ; echo \\\$LD_LIBRARY_PATH ; cd /tmp ; BASEFILE=${THUMBNAILSBASE}/,, ; echo BASEFILE ; echo \\\$BASEFILE ; FILEINDEX=\\\$(echo \\\$BASEFILE | awk -F'[/.]' '{print \\\$8}') ; echo FILEINDEX : ; echo \\\$FILEINDEX ; wget ${THUMBNAILSBASE}/,, ; cd --  ; echo Check /tmp content : ; ls -alsth /tmp ; magick convert -define png:size=300x100 /tmp/*.png -auto-orient -thumbnail 180x110 -unsharp 0x.5 /tmp/thumbnail\\\$FILEINDEX.png  ; scp /tmp/thumbnail\\\$FILEINDEX.png ${THUMBNAILSBASE} ; echo CHECK thumbnail result ; ls -alsth /tmp \"" 

clock2=`date +%s`

durationthumbnails=`expr $clock2 - $clock1`

echo ""
echo ""
echo ""
echo DURATION THUMBNAILS : $durationthumbnails seconds
