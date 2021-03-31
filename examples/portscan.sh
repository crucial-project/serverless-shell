#!/bin/bash -x

export filename=/mnt/efsimttsp/poshdata/apps/portscan/test_80_40GB.json
#export filename=$HOME/efs/poshdata/apps/portscan/test_80_40GB.json
export mrt_file=/mnt/efsimttsp/poshdata/apps/portscan/2019-10-12.0500.mrt
#export mrt_file=$HOME/efs/poshdata/apps/portscan/2019-10-12.0500.mrt
export json_file=$HOME/efs/poshdata/apps/portscan/test_80_40GB.json 
export sec_file=/home/ec2-user/efs/sec/logs/log20170314.csv 

clock1=`date +%s` 

#head -n 10 /dev/shm/config.properties | parallel echo
#head -n 1000 $json_file | parallel echo
#head -n 10 $json_file | parallel -j10 -I,, --env sshell "sshell \" echo LAMBDA: ; echo ,, | zannotate -routing -routing-mrt-file=$mrt_file -input-file-type=json \""
head -n 100000 $HOME/efs/poshdata/apps/portscan/test_80_40GB.json | parallel -j10 -I,, --env sshell "sshell \"  echo ,, | zannotate -routing -routing-mrt-file=$mrt_file -input-file-type=json \""
#cat $json_file | parallel -j10 -I,, --env sshell "sshell \" true \""
#head -n 10 /dev/shm/config.properties | parallel -j10 -I,, --env sshell "sshell \" echo ,, \""
#head -n 1000 $sec_file | parallel -j10 -I,, --env sshell "sshell \" echo ,, \""
#head -n 10 $HOME/efs/poshdata/apps/portscan/test_80_40GB.json | parallel echo
#head -n 100 $json_file | parallel -j10 -I,, --env sshell "sshell \" echo ,, | zannotate -routing -routing-mrt-file=$mrt_file -input-file-type=json \""
#head -n 100 $json_file | parallel -j10 -I,, --env sshell "sshell \" echo ,, \""
#head -n 10000 $json_file | $zannotate -routing -routing-mrt-file=$mrt_file -input-file-type=json 

clock2=`date +%s`
durationportscan=`expr $clock2 - $clock1` 


sleep 2
echo ""
echo ""
echo DURATION PORT SCAN : $durationportscan seconds
