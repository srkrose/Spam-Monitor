#!/bin/bash

source /home/sample/scripts/dataset.sh

function mail_frozen() {

	host=$(hostname)

	rfrmv=$(exiqgrep -zbr root@$host -o 3600 -i | wc -l)

	exiqgrep -zbr root@$host -o 3600 -i | xargs exim -Mrm

	ufrmv=$(exiqgrep -zb -o 86400 | grep -v "root@$host" | awk {'print $1'} | wc -l)

	exiqgrep -zb -o 86400 | grep -v "root@$host" | awk {'print $1'} | xargs exim -Mrm

	rfnow=$(exiqgrep -zbr root@$host -i | wc -l)

	ufnow=$(exiqgrep -zb | grep -v "root@$host" | awk {'print $1'} | wc -l)
}

function mail_queue() {

	sqrmv=$(exiqgrep -xb -o 3600 | grep "<>" | awk {'print $1'} | wc -l)

	exiqgrep -xb -o 3600 | grep "<>" | awk {'print $1'} | xargs exim -Mrm

	uqrmv=$(exiqgrep -xb -o 172800 | grep -v "<>" | awk {'print $1'} | wc -l)

	exiqgrep -xb -o 172800 | grep -v "<>" | awk {'print $1'} | xargs exim -Mrm

	qtotal=$(exiqgrep -xb | awk {'print $1'} | wc -l)

	systemq=$(exiqgrep -xb | grep "<>")
	sqnow=$(exiqgrep -xb | grep "<>" | awk {'print $1'} | wc -l)

	userq=$(exiqgrep -xb | grep -v "<>")
	uqnow=$(exiqgrep -xb | grep -v "<>" | awk {'print $1'} | wc -l)

	if [ "$uqnow" -gt 50 ]; then
		queue_data

		content=$(echo "Mail Queue - $uqnow")

		send_sms

		send_mail
	fi
}

function header() {
	if [ ! -f $svrlogs/spam/mailqueue/mailqueue_$date.txt ]; then
		printf "%-20s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n" "DATE_TIME" "RF_RMV" "RF_NOW" "UF_RMV" "UF_NOW" "SQ_RMV" "SQ_NOW" "UQ_RMV" "UQ_NOW" >>$svrlogs/spam/mailqueue/mailqueue_$date.txt
	fi
}

function print_data() {

	header

	printf "%-20s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n" "$time" "$rfrmv" "$rfnow" "$ufrmv" "$ufnow" "$sqrmv" "$sqnow" "$uqrmv" "$uqnow" >>$svrlogs/spam/mailqueue/mailqueue_$date.txt
}

function queue_data() {

	echo "Mail Queue - $qtotal" >>$svrlogs/spam/mailqueue/mqcheck_$time.txt
	echo "" >>$svrlogs/spam/mailqueue/mqcheck_$time.txt

	echo "System:" >>$svrlogs/spam/mailqueue/mqcheck_$time.txt
	echo "Total: $sqnow" >>$svrlogs/spam/mailqueue/mqcheck_$time.txt
	echo "$systemq" >>$svrlogs/spam/mailqueue/mqcheck_$time.txt
	echo "" >>$svrlogs/spam/mailqueue/mqcheck_$time.txt

	echo "User:" >>$svrlogs/spam/mailqueue/mqcheck_$time.txt
	echo "Total: $uqnow" >>$svrlogs/spam/mailqueue/mqcheck_$time.txt
	echo "$userq" >>$svrlogs/spam/mailqueue/mqcheck_$time.txt
}

function send_sms() {
	message=$(echo "$hostname: $content")

	#php $scripts/send_sms.php "$message" "$validation"

	curl -X POST -H "Content-type: application/json" --data "{\"text\":\"$message\"}" $spamemailslack
}

function send_mail() {
	echo "SUBJECT: Mail Queue Check - $hostname - $(date +"%F")" >>$svrlogs/mail/mqmail_$time.txt
	echo "FROM: Mail Queue Check <root@$(hostname)>" >>$svrlogs/mail/mqmail_$time.txt
	echo "" >>$svrlogs/mail/mqmail_$time.txt
	echo "$(cat $svrlogs/spam/mailqueue/mqcheck_$time.txt)" >>$svrlogs/mail/mqmail_$time.txt
	sendmail "$emailmo,$emailmg" <$svrlogs/mail/mqmail_$time.txt
}

mail_frozen

mail_queue

print_data
