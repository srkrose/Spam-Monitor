#!/bin/bash

source /home/sample/scripts/dataset.sh

category="$1"
username="$2"
fail="$3"
action="$4"

function send_mail() {
	mtime=$(date +"%F_%T")

	echo "SUBJECT: Hourly Spam Check - $hostname - $(date +"%F %T")" >>$svrlogs/mail/spammail_$mtime.txt
	echo "FROM: Hourly Spam Check <root@$(hostname)>" >>$svrlogs/mail/spammail_$mtime.txt
	echo "" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Date:" "$(date +"%F")" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Time:" "$(date +"%T")" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Category:" "$category" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Username:" "$username" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Failed:" "$fail" >>$svrlogs/mail/spammail_$mtime.txt
	printf "%-10s %20s\n" "Status:" "$action" >>$svrlogs/mail/spammail_$mtime.txt
	sendmail "$emailmo,$emailmg" <$svrlogs/mail/spammail_$mtime.txt
}

send_mail
