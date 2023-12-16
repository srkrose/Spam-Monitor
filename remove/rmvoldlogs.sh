#!/bin/bash

source /home/sample/scripts/dataset.sh

function rmvold_logs() {
	directory=($(cat $scripts/logdir.txt))
	count=${#directory[@]}

	for ((i = 0; i < count; i++)); do
		dirpath="$svrlogs/${directory[i]}"
		oldlogs=($(find $dirpath -maxdepth 1 -mtime +21 -type f))

		for file in "${oldlogs[@]}"; do
			rm -f $file
			echo "$(date +"%F %T") Removed - $file" >>$svrlogs/logs/rmvoldlogs_$logtime.txt
		done
	done
}

rmvold_logs
