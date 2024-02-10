#!/bin/bash

source /home/sample/scripts/dataset.sh

function smtp_outbound() {
	sh $scripts/spam/smtpoutbound.sh
}

function cwd_home() {
	sh $scripts/spam/cwdhome.sh
}

function dovecot_plain() {
	sh $scripts/spam/dovecotplain.sh
}

function dovecot_login() {
	sh $scripts/spam/dovecotlogin.sh
}

function spam_reject() {
	sh $scripts/spam/spamreject.sh
}

function mail_queue() {
	sh $scripts/spam/mailqueue.sh
}

dovecot_login

cwd_home

dovecot_plain

smtp_outbound

spam_reject

mail_queue
