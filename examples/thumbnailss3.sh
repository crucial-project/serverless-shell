#!/bin/bash -x

S3BUCKET="amaheo"
AWSREGION="s3-website-us-east-1"
THUMBNAILSBASES3="s3://amaheo/thumbnails"
THUMBNAILSBASEZONE="http://amaheo.s3-website-us-east-1.amazonaws.com/thumbnails"
THUMBNAILSBASE="http://amaheo.s3.amazonaws.com/thumbnails"
SIGNATURE=`echo -en ${stringToSign} | openssl sha1 -hmac ${S3SECRETKEY} -binary | base64`

#file=/path/to/file/to/upload.tar.gz
bucket=amaheo
#resource="/${bucket}/${file}"
contentType="application/x-iso9660-image"
dateValue=`date -R`
stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
#s3Key=xxxxxxxxxxxxxxxxxxxx
#s3Secret=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`
#curl -X PUT -T "${file}" \
#  -H "Host: ${bucket}.s3.amazonaws.com" \
#  -H "Date: ${dateValue}" \
#  -H "Content-Type: ${contentType}" \
#  https://${bucket}.s3.amazonaws.com/${file}

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

sshell "rm -rf /tmp/*"

echo ""
echo ""
echo START PROCESSING

clock1=`date +%s`

head -n 20 thumbnails_refined_content.out | parallel  -I,, --env sshell "sshell \" rm -rf /tmp/pic* ; rm -rf /tmp/THUMBNAIL* ;  echo ======= ; echo BEGIN ; echo  ======= ; echo do pwd ; pwd ; export HOME=/var/task ; echo HOME ; echo echo \\\$HOME ; export PYTHONHOME=/opt/python/lib/python2.7:\\\$PYTHONHOME ; export PYTHONPATH=/opt/python/lib/python2.7/site-packages:/opt/python/lib/python2.7:\\\$PYTHONPATH ;  echo PYTHONHOME : ; echo \\\$PYTHONHOME ; echo PYTHONPATH : ; echo \\\$PYTHONPATH ; echo LD_LIBRARY_PATH ; echo \\\$LD_LIBRARY_PATH ; cd /tmp ; BASEFILE=${THUMBNAILSBASEZONE}/,, ; echo BASEFILE ; echo \\\$BASEFILE ; FILEINDEX=\\\$(echo \\\$BASEFILE | awk -F'[/.]' '{print \\\$8}') ; echo FILEINDEX : ; echo \\\$FILEINDEX ; wget ${THUMBNAILSBASEZONE}/,, ; cd --  ; echo Check /tmp content : ; ls -alsth /tmp ; echo SLEEP ; sleep 2 ; magick convert -define png:size=300x100 /tmp/*.png -auto-orient -thumbnail 180x110 -unsharp 0x.5 /tmp/THUMBNAIL\\\$FILEINDEX.png ; echo CHECK thumbnail result ; ls -alsth /tmp ; echo SLEEP ; sleep 2 ; echo CURL THUMBNAIL TO AWS S3 BUCKET ; curl -X POST -T /tmp/THUMBNAIL\\\$FILEINDEX.png -H 'Host: ${S3BUCKET}.${AWSREGION}.amazonaws.com' -H 'Date: ${dateValue}' -H 'Content-Type: ${contentType}' ${THUMBNAILSBASE}/THUMBNAILS\\\$FILEINDEX-0.png ;  aws s3 cp /tmp/THUMBNAIL\\\$FILEINDEX.png s3://amaheo/thumbnails ; rm -rf /tmp/pic* ; rm -rf /tmp/THUMBNAIL* ; echo ======== ; echo END ; echo ======== \""
clock2=`date +%s`

durationthumbnails=`expr $clock2 - $clock1`

echo ""
echo ""
echo ""
echo DURATION THUMBNAILS : $durationthumbnails seconds


echo "CHECK AWS LAMBDA /tmp"
sshell "ls -alsth /tmp"
