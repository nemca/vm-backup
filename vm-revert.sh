#! /usr/bin/env bash

VM=$1
SN=$2
DATA_DIR="/var/glusterfs/vm_images_and_config"
BACKUP_DIR="/snapshots"

if [[ -z $1 ]]; then
	echo "Virtual machine name not specify"
	exit 0
fi
if [[ -z $2 ]]; then
	echo "Snapshot name not specify"
	exit 0
fi

if [[ ! -d $BACKUP_DIR/$VM/$SN ]]; then
	echo "Backup not found"
	exit 1
fi

err_msg=`rsync -a $BACKUP_DIR/$VM/$SN/$VM.qcow2 $DATA_DIR/images/$VM.qcow2 2>&1 1>/dev/null`
if [[ $? != 0 ]]; then
	echo "Can't revert $VM image: $err_msg"
	exit 2
fi

err_msg=`rsync -a $BACKUP_DIR/$VM/$SN/$VM.xml $DATA_DIR/qemu/$VM.xml 2>&1 1>/dev/null`
if [[ $? != 0 ]]; then
	echo "Can't revert $VM config: $err_msg"
	exit 3
fi
