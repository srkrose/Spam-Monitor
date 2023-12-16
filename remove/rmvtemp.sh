#!/bin/bash

source /home/sample/scripts/dataset.sh

tempoldlogs=($(find $temp -type f))

for file in "${tempoldlogs[@]}"; do
	rm -f $file
	echo "$(date +"%F %T") Removed - $file" >>$svrlogs/logs/templogs_$logtime.txt
done
