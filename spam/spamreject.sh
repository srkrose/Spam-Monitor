#!/bin/bash

source /home/sample/scripts/dataset.sh

function delivery_log() {
	whmapi1 emailtrack_search defer=1 failure=1 | grep -B 9 -A 14 -ie "unexpected volume or user complaints\|considered spam\|looks like SPAM\|reported as SPAM\|forward this error to abuse_rbl\|mailbox not found\|mailbox unavailable\|user no longer on system\|user does not exist\|mailbox is disabled\|reach does not exist\|rejected per SPAM policy\|Reject due to policy restrictions\|rejected due to local policy\|recipient address rejected" | grep -w "actiontime:\|domain:\|email:\|message:\|senderauth:\|type:\|user:" | grep -A 6 "$(date -d '1 hours ago' +"%F %H:")" >>$temp/emailtrack_$time.txt
}

function spam_reject() {
	if [ -r $temp/emailtrack_$time.txt ] && [ -s $temp/emailtrack_$time.txt ]; then
		user=$(cat $temp/emailtrack_$time.txt | grep -w "user:" | awk '{print $NF}' | sort | uniq)

		while IFS= read -r line; do
			data=$(cat $temp/emailtrack_$time.txt | grep -B 6 -w "$line")

			ecount=$(echo "$data" | grep -w "email:" | awk '{print $NF}' | sort | uniq | wc -l)

			if [ $ecount -eq 1 ]; then
				category=$(echo "$data" | grep -w "senderauth:" | awk '{print $NF}' | sort | uniq)
				email=$(echo "$data" | grep -w "email:" | awk '{print $NF}' | sort | uniq)
				domain=$(echo "$email" | awk -F@ '{print $NF}')
				username=$line
				defer=$(echo "$data" | grep -w "type: defer" | wc -l)
				fail=$(echo "$data" | grep -w "type: failure" | wc -l)
				status=$(whmapi1 accountsummary user=$username | grep -i "outgoing_mail_suspended:" | awk '{print $2}')

				if [ "$status" -eq 0 ]; then
					header

					printf "%-20s %-15s %-10s %-10s %-15s %-70s\n" "$time" "$username" "$defer" "$fail" "Active" "$email" >>$svrlogs/spam/hourlycheck/spamreject_$date.txt

					record_check
				else
					header

					printf "%-20s %-15s %-10s %-10s %-15s %-70s\n" "$time" "$username" "$defer" "$fail" "Suspended" "$email" >>$svrlogs/spam/hourlycheck/spamreject_$date.txt
				fi
			fi
		done <<<"$user"
	fi
}

function header() {
	if [ ! -f $svrlogs/spam/hourlycheck/spamreject_$date.txt ]; then
		printf "%-20s %-15s %-10s %-10s %-15s %-70s\n" "DATE_TIME" "USER" "DEFER" "FAIL" "STATUS" "EMAIL" >>$svrlogs/spam/hourlycheck/spamreject_$date.txt
	fi
}

function record_check() {
	if [[ $defer -gt 10 || $fail -gt 5 ]]; then
		spamrecord=($(find $svrlogs/spam/hourlycheck -type f -name "spamreject*" -exec ls -lat {} + | grep "$(date -d '1 hours ago' +"%F")" | head -1 | awk '{print $NF}'))

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

	php $scripts/send_sms.php "$message" "$validation"

	curl -X POST -H "Content-type: application/json" --data "{\"text\":\"$message\"}" $spamemailslack
}

function send_mail() {
	sh $scripts/spam/spammail.sh "$category" "$username" "$defer" "$fail" "$action"
}

delivery_log

spam_reject
