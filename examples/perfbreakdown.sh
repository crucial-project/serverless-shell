#!/usr/bin/env bash


buildperfbreakdownthumbnailssummary() {

 durationnanodownloadacc=0
 durationnanoconvertacc=0
 durationnanouploadacc=0

 cat $1 | grep durationdownload > durationdownload.out
 cat $1 | grep durationconvert > durationconvert.out
 cat $1 | grep durationupload > durationupload.out
 cat $1 | grep durationoverall > durationoverall.out

 echo 1st arg: $1
 echo 2nd arg: $2

 #cat durationio.out
 #cat durationprocess.out

 # Read Download file 
 while read l; do
   measure=$(echo ${l} | awk '{print $3}')
   durationnanodownloadacc=$((durationnanodownloadacc+$measure))
 done < durationdownload.out

 # Read Convert file
 while read l; do
   measure=$(echo ${l} | awk '{print $3}')
   durationnanoconvertacc=$((durationnanoconvertacc+$measure))
 done < durationconvert.out

 # Read Upload file
 while read l; do
   measure=$(echo ${l} | awk '{print $3}')
 #  echo "time upload: $measure"
   durationnanouploadacc=$((durationnanouploadacc+$measure))
 done < durationupload.out

 # Read Overall file 
 while read l; do
   measure=$(echo ${l} | awk '{print $3}')
   echo mesure overall: $measure
   durationoverall=$measure
 done < durationoverall.out


 echo "duration Download: $durationnanodownloadacc nanoseconds"
 echo "duration Convert: $durationnanoconvertacc nanoseconds"
 echo "duration Upload: $durationnanouploadacc nanoseconds"

 #echo $($durationnanoioacc/1000000)
 #echo $($durationnanocomputeacc/1000000)
 #echo $($durationnanosyncacc/1000000)

 durationdownloadaccsecs=$((durationnanodownloadacc / 1000000000))
 durationconvertaccsecs=$((durationnanoconvertacc / 1000000000))
 durationuploadaccsecs=$((durationnanouploadacc / 1000000000))

 #durationioavg=$((durationioaccsecs / ${INPUT}))
 #durationcomputeavg=$((durationcomputeaccsecs / ${INPUT}))
 #durationsyncavg=$((durationsyncaccsecs / ${INPUT}))

 #durationioacc=$((durationnanoioacc / 1000000))
 #durationcomputeacc=$((durationnanocomputeacc / 1000000))
 #durationsyncacc=$((durationnanosyncacc / 1000000))

 durationdownloadaccsecs=$((durationdownloadaccsecs/$2))
 durationconvertaccsecs=$((durationconvertaccsecs/$2))
 durationuploadaccsecs=$((durationuploadaccsecs/$2))
 durationinvoke=$(($durationoverall-$durationdownloadaccsecs-$durationconvertaccsecs-$durationuploadaccsecs))

 echo "Thumbnails - Performance Breakdown Summary"

 echo "duration Download: $durationdownloadaccsecs seconds"
 echo "duration Convert: $durationconvertaccsecs seconds"
 echo "duration Upload: $durationuploadaccsecs seconds"
 echo "duration lambda invoke: $durationinvoke seconds"
 echo "Overall duration: $durationoverall seconds"

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

buildperfbreakdownthumbnailssummary $1 $2
