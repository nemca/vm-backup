#! /usr/bin/env bash

#MAILTO=${MAILTO:-root}

_timeNow() {
	date +"%Y-%m-%d %H:%M:%S"
}

log() {
	if [[ -z $LOG_PATH ]]; then
		echo `_timeNow` "[INFO] $1"
	else
		echo `_timeNow` "[INFO] $1" >> $LOG_PATH
	fi
}

error() {
	if [[ -z $LOG_PATH ]]; then
		echo `_timeNow` "[ERROR] $1"
	else
		echo `_timeNow` "[ERROR] $1" >> $LOG_PATH
	fi
	if [[ -n $MAILTO ]]; then
		echo `_timeNow` "[ERROR] $1" | mail -s "[ERROR] `basename $0` on `hostname -f`" $MAILTO
	fi
	exit 1
}

warning() {
	if [[ -z $LOG_PATH ]]; then
		echo `_timeNow` "[WARNING] $1"
	else
		echo `_timeNow` "[WARNING] $1" >> $LOG_PATH
	fi
}

if [[ -n $LOG_PATH ]]; then
	err_msg=`touch $LOG_PATH 2>&1 >/dev/null`
	if [[ $? != 0 ]]; then
		_error "$err_msg"
	fi
fi
