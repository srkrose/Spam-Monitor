#!/bin/bash

source /home/sample/scripts/dataset.sh

function exim_mainlog() {
	grep -i "cwd=/home" /var/log/exim_mainlog | grep -ie "$(date -d '1 hour ago' +"%F %H:")" | awk '{print "DATE: "$1,"\tUSER: "$3}' | sed 's/cwd=\/home\///' | sort | uniq -c | sort -nr >>$temp/cwdhome_$time.txt
}

function cwd_home() {
	if [ -r $temp/cwdhome_$time.txt ] && [ -s $temp/cwdhome_$time.txt ]; then
		category="cwdhome"

		while IFS= read -r line || [[ -n "$line" ]]; do
			mailcount=$(echo "$line" | awk '{print $1}')

			if [ "$mailcount" -gt 90 ]; then
				username=$(echo "$line" | awk '{print $NF}' | awk -F/ '{print $1}')
				count=($(whmapi1 emailtrack_stats user=$username startdate=$(date -d '1 hours ago' +"%s") enddate=$(date -d 'now' +"%s") | grep -ie "DEFERCOUNT\|FAILCOUNT"))
				difer=$(echo -e "${count[1]}")
				fail=$(echo -e "${count[5]}")
				status=$(whmapi1 accountsummary user=$username | grep -i "outgoing_mail_suspended:" | awk '{print $2}')

				if [ "$status" -eq 0 ]; then
					header

					printf "%-20s %-15s %-10s %-10s %-15s\n" "$time" "$username" "$difer" "$fail" "Active" >>$svrlogs/spam/hourlycheck/cwdhome_$date.txt

					notify
				else
					header

					printf "%-20s %-15s %-10s %-10s %-15s\n" "$time" "$username" "$difer" "$fail" "Suspended" >>$svrlogs/spam/hourlycheck/cwdhome_$date.txt
				fi
			fi
		done <"$temp/cwdhome_$time.txt"
	fi
}

function header() {
	if [ ! -f $svrlogs/spam/hourlycheck/cwdhome_$date.txt ]; then
		printf "%-20s %-15s %-10s %-10s %-15s\n" "DATE_TIME" "USER" "DIFER" "FAIL" "STATUS" >>$svrlogs/spam/hourlycheck/cwdhome_$date.txt
	fi
}

function notify() {
	if [ "$fail" -gt 10 ]; then
		suspend_user

		content=$(echo "$username: last hour failed - $fail *$category* $action")

		send_sms

		send_mail
	fi
}

function suspend_user() {
	result=$(whmapi1 suspend_outgoing_email user=$username | grep "result:" | awk '{print $NF}')

	if [ $result -ne 0 ]; then
		action="SUSPENDED"
	else
		action="NOT SUSPENDED"
	fi
}

function send_sms() {
	message=$(echo "$hostname: $content")

	php $scripts/send_sms.php "$message" "$validation"

	curl -X POST -H "Content-type: application/json" --data "{\"text\":\"$message\"}" $spamemailslack
}

function send_mail() {
	sh $scripts/spam/spammail.sh "$category" "$username" "$fail" "$action"
}

exim_mainlog

cwd_home
