#!/bin/bash

source /home/sample/scripts/dataset.sh

function main_dir() {
	if [[ ! -d "$svrlogs" ]]; then
		mkdir $svrlogs
		chown $cpuser: $svrlogs
	fi
}

function sub_dir() {
	directory=($(cat $scripts/logdir.txt))
	count=${#directory[@]}

	for ((i = 0; i < count; i++)); do
		dirpath="$svrlogs/${directory[i]}"

		if [[ ! -d "$dirpath" ]]; then
			mkdir $dirpath
			chown $cpuser: $dirpath
		fi
	done
}

main_dir

sub_dir
