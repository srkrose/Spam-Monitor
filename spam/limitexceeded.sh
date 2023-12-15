#!/bin/bash

source /home/sample/scripts/dataset.sh

function exim_mainlog() {
	cat /var/log/exim_mainlog | awk -v Date1=$(date -d '5 minutes ago' +%Y-%m-%d) -v Date2=$(date -d '1 minutes ago' +%Y-%m-%d) -v Time1=$(date -d '5 minutes ago' +%H:%M:00) -v Time2=$(date -d '1 minutes ago' +%H:%M:59) '{if ($1 >= Date1 && $1 <= Date2) {if ($2 >= Time1 && $2 <= Time2) print $0}}' | grep "exceeded the max emails per hour" | awk '{for(i=1;i<=NF;i++) {if($i=="exceeded") {if($7=="defer") printf "%-19s %-17s %-16s %-50s %-70s\n","DATE: "$1,"TIME: "$2,"STAT: defer","FROM: "$(i-2),"TO: "$5; else if($NF=="discarded.") printf "%-19s %-17s %-16s %-50s %-70s\n","DATE: "$1,"TIME: "$2,"STAT: discard","FROM: "$(i-2),"TO: "$5}}}' >>$temp/limitexceeded_$time.txt
}

function limit_exceeded() {
	if [ -r $temp/limitexceeded_$time.txt ] && [ -s $temp/limitexceeded_$time.txt ]; then

		cat $temp/limitexceeded_$time.txt >>$svrlogs/spam/limitexceeded/lelog_$date.txt

		domains=$(cat $temp/limitexceeded_$time.txt | awk '{print $8}' | sort | uniq)

		while IFS= read -r line; do
			data=$(cat $temp/limitexceeded_$time.txt | grep -w "$line")

			defer=$(echo "$data" | grep -w "defer" | wc -l)
			fail=$(echo "$data" | grep -w "discard" | wc -l)

			if [[ $defer -gt 10 || $fail -gt 10 ]]; then
				recipients=$(echo "$data" | awk -F'@' '{print $NF}' | awk -F'.' '{print $1}' | sort | uniq -c | sort -nr)

				mailsp=(hotmail live outlook msn gmail googlemail yahoo ymail aol)
				count=${#mailsp[@]}

				num=0
				snum=0

				for ((i = 0; i < count; i++)); do
					msp=$(echo "$recipients" | grep -w ${mailsp[i]} | wc -l)

					if [ $msp -ne 0 ]; then
						num=$((num + msp))

						if [[ "${mailsp[i]}" == "hotmail" || "${mailsp[i]}" == "live" || "${mailsp[i]}" == "gmail" || "${mailsp[i]}" == "yahoo" ]]; then
							snum=$((snum + msp))
						fi
					fi
				done

				if [[ $num -ge 10 && $snum -ge 5 || $fail -ge 20 ]]; then
					domain=$(echo "$line")
					username=$(whmapi1 getdomainowner domain=$domain | grep -i "user:" | awk '{print $2}')
					status=$(whmapi1 accountsummary user=$username | grep -i "outgoing_mail_suspended:" | awk '{print $2}')

					if [ "$status" -eq 0 ]; then
						header

						printf "%-20s %-15s %-10s %-10s %-15s %-50s\n" "$time" "$username" "$defer" "$fail" "Active" "$domain" >>$svrlogs/spam/limitexceeded/limitexceeded_$date.txt

						suspend_user
					else
						header

						printf "%-20s %-15s %-10s %-10s %-15s %-50s\n" "$time" "$username" "$defer" "$fail" "Suspended" "$domain" >>$svrlogs/spam/limitexceeded/limitexceeded_$date.txt
					fi
				fi
			fi
		done <<<"$domains"
	fi
}

function header() {
	if [ ! -f $svrlogs/spam/limitexceeded/limitexceeded_$date.txt ]; then
		printf "%-20s %-15s %-10s %-10s %-15s %-50s\n" "DATE_TIME" "USER" "DEFER" "FAIL" "STATUS" "DOMAIN" >>$svrlogs/spam/limitexceeded/limitexceeded_$date.txt
	fi
}

function suspend_user() {
	result=$(whmapi1 suspend_outgoing_email user=$username | grep "result:" | awk '{print $NF}')

	if [ $result -ne 0 ]; then
		action="SUSPENDED"

		content=$(echo "$username: last 5 min: Deferred - $defer - Failed - $fail *Limit Exceeded* $action")

		send_sms

		send_mail
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
	mtime=$(date +"%F_%T")

	echo "SUBJECT: Limit Exceeded Spam Check - $hostname - $(date +"%F %T")" >>$svrlogs/mail/spammail_$mtime.txt
	echo "FROM: Limit Exceeded Spam Check <root@$(hostname)>" >>$svrlogs/mail/spammail_$mtime.txt
	echo "" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Date:" "$(date +"%F")" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Time:" "$(date +"%T")" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Category:" "limit exceeded" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Username:" "$username" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Deferred:" "$defer" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Failed:" "$fail" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Status:" "$action" >>$svrlogs/mail/spammail_$mtime.txt
	sendmail "$emailmo,$emailmg" <$svrlogs/mail/spammail_$mtime.txt
}

exim_mainlog

limit_exceeded
