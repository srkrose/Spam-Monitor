#!/bin/bash

source /home/sample/scripts/dataset.sh

function exim_mainlog() {
	cat /var/log/exim_mainlog | grep -ie "$(date -d '1 hour ago' +"%F %H:")" | grep -i "SMTP connection outbound" | awk '{print "DATE: "$1,"\tDOMAIN: "$9}' | sort | uniq -c | sort -nr >>$temp/smtpoutbound_$time.txt
}

function smtp_outbound() {
	if [ -r $temp/smtpoutbound_$time.txt ] && [ -s $temp/smtpoutbound_$time.txt ]; then
		category="smtpoutbound"

		while IFS= read -r line || [[ -n "$line" ]]; do
			mailcount=$(echo "$line" | awk '{print $1}')

			if [ "$mailcount" -gt 90 ]; then
				domain=$(echo "$line" | awk '{print $NF}')
				username=$(whmapi1 getdomainowner domain=$domain | grep -i "user:" | awk '{print $2}')
				count=($(whmapi1 emailtrack_stats user=$username startdate=$(date -d '1 hours ago' +"%s") enddate=$(date -d 'now' +"%s") | grep -ie "DEFERCOUNT\|FAILCOUNT"))
				defer=$(echo -e "${count[1]}")
				fail=$(echo -e "${count[5]}")
				status=$(whmapi1 accountsummary user=$username | grep -i "outgoing_mail_suspended:" | awk '{print $2}')

				if [ "$status" -eq 0 ]; then
					header

					printf "%-20s %-15s %-10s %-10s %-15s %-50s\n" "$time" "$username" "$defer" "$fail" "Active" "$domain" >>$svrlogs/spam/hourlycheck/smtpoutbound_$date.txt

					record_check
				else
					header

					printf "%-20s %-15s %-10s %-10s %-15s %-50s\n" "$time" "$username" "$defer" "$fail" "Suspended" "$domain" >>$svrlogs/spam/hourlycheck/smtpoutbound_$date.txt
				fi
			fi
		done <"$temp/smtpoutbound_$time.txt"
	fi
}

function header() {
	if [ ! -f $svrlogs/spam/hourlycheck/smtpoutbound_$date.txt ]; then
		printf "%-20s %-15s %-10s %-10s %-15s %-50s\n" "DATE_TIME" "USER" "DEFER" "FAIL" "STATUS" "DOMAIN" >>$svrlogs/spam/hourlycheck/smtpoutbound_$date.txt
	fi
}

function record_check() {
	if [[ $defer -gt 30 || $fail -gt 10 ]]; then
		spamrecord=($(find $svrlogs/spam/hourlycheck -type f -name "dovecotlogin*" -exec ls -lat {} + | grep "$(date -d '1 hours ago' +"%F")" | head -1 | awk '{print $NF}'))

		prev=$(cat $spamrecord | awk -v username=$username '{if($2==username) print}' | grep "$(date -d '1 hours ago' +"%F_%H:")")

		if [[ ! -z "$prev" ]]; then
			suspend_user

			notify
		fi
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

function notify() {
	content=$(echo "$username: last hour: Deferred - $defer - Failed - $fail *$category* $action")

	send_sms

	send_mail
}

function send_sms() {
	message=$(echo "$hostname: $content")

	#php $scripts/send_sms.php "$message" "$validation"

	curl -X POST -H "Content-type: application/json" --data "{\"text\":\"$message\"}" $spamemailslack
}

function send_mail() {
	sh $scripts/spam/spammail.sh "$category" "$username" "$defer" "$fail" "$action"
}

exim_mainlog

smtp_outbound
