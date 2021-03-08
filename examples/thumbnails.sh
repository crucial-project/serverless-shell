#!/bin/bash -x

THUMBNAILSBASE="s3://amaheo/thumbnails"

echo "Display AWS S3 THUMBNAILS content : "
#aws s3 ls $THUMBNAILSBASE/
#aws s3 ls $THUMBNAILSBASE/ | wc -l
#aws s3 ls $THUMBNAILSBASE/ > thumbnails_content.out

echo ""
echo ""
echo cat thumbnails content :
cat thumbnails_content.out 

clock1=$(date +%s)

cat thumbnails_content.out | parallel -j100 -I,, --env sshell "sshell \" ./magick ${THUMBNAILSBASE}/,, \"" 

clock2=$(date +%s)

durationthumbnails=`expr $clock2 - $clock1`

echo duration thumbnails: $durationthumbnails seconds
