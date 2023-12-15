#!/bin/bash

source /home/sample/scripts/dataset.sh

function exim_mainlog() {
	grep -ie "$(date -d '1 hour ago' +"%F %H:")" /var/log/exim_mainlog | egrep -o 'dovecot_login[^ ]+' | sed 's/dovecot_login://' | sort | uniq -c | sort -nr >>$temp/dovecotlogin_$time.txt
}

function dovecot_login() {
	if [ -r $temp/dovecotlogin_$time.txt ] && [ -s $temp/dovecotlogin_$time.txt ]; then
		category="dovecotlogin"

		while IFS= read -r line || [[ -n "$line" ]]; do
			mailcount=$(echo "$line" | awk '{print $1}')

			if [ "$mailcount" -gt 90 ]; then
				email=$(echo "$line" | awk '{print $NF}')
				domain=$(echo "$email" | awk -F@ '{print $NF}')
				username=$(whmapi1 getdomainowner domain=$domain | grep -i "user:" | awk '{print $2}')
				count=($(whmapi1 emailtrack_stats user=$username startdate=$(date -d '1 hours ago' +"%s") enddate=$(date -d 'now' +"%s") | grep -ie "DEFERCOUNT\|FAILCOUNT"))
				difer=$(echo -e "${count[1]}")
				fail=$(echo -e "${count[5]}")
				status=$(whmapi1 accountsummary user=$username | grep -i "outgoing_mail_suspended:" | awk '{print $2}')

				if [ "$status" -eq 0 ]; then
					header

					printf "%-20s %-15s %-10s %-10s %-15s %-70s\n" "$time" "$username" "$difer" "$fail" "Active" "$email" >>$svrlogs/spam/hourlycheck/dovecotlogin_$date.txt

					notify
				else
					header

					printf "%-20s %-15s %-10s %-10s %-15s %-70s\n" "$time" "$username" "$difer" "$fail" "Suspended" "$email" >>$svrlogs/spam/hourlycheck/dovecotlogin_$date.txt
				fi
			fi
		done <"$temp/dovecotlogin_$time.txt"
	fi
}

function header() {
	if [ ! -f $svrlogs/spam/hourlycheck/dovecotlogin_$date.txt ]; then
		printf "%-20s %-15s %-10s %-10s %-15s %-70s\n" "DATE_TIME" "USER" "DIFER" "FAIL" "STATUS" "EMAIL" >>$svrlogs/spam/hourlycheck/dovecotlogin_$date.txt
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

dovecot_login
