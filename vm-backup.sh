#! /usr/bin/env bash

DATE=`date +%F`
DATA_DIR="/var/glusterfs/vm_images_and_config/images"
BACKUP_DIR="/snapshots"
LOG_PATH="/var/log/vm-backup.log"

# logging
if [[ -r logging.sh ]]; then
	source logging.sh
fi

function get_vms() {
	VM=`virsh list --state-running --name`
	if [[ $? != 0 ]]; then
		log "VM's not found" && exit 0
	fi
}

# get disk
function get_disk() {
	DISK=`virsh domblklist $1 | awk '/qcow2/ { print $1 }'`
}

function delete_temp_snapshot() {
	rm -f $BACKUP_DIR/$VM-snapshot.qcow2 1>/dev/null 2>&1
}

# create snapshot
function create_snapshot() {
	err_msg=`virsh snapshot-create-as --domain $1 $DATE --diskspec $DISK,file=$BACKUP_DIR/$1-snapshot.qcow2 --disk-only --atomic 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Cant't create $1 snapshot: $err_msg"
		delete_temp_snapshot && exit 1
	fi
}

function create_snapshot_dir() {
	if [[ ! -d $BACKUP_DIR/$1/$DATE ]]; then
		mkdir -p $BACKUP_DIR/$1/$DATE
	fi
}

function backup_image() {
	err_msg=`rsync -a $DATA_DIR/$1.qcow2 $BACKUP_DIR/$1/$DATE/$1.qcow2 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't backup $1 image: $err_msg"
		delete_temp_snapshot && exit 2
	fi
}

function blockcommit_image() {
	err_msg=`virsh blockcommit $1 $DISK --active --verbose --pivot 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't do blockcommit $1: $err_msg"
		delete_temp_snapshot && exit 3
	fi
}

function delete_snapshot() {
	err_msg=`virsh snapshot-delete --domain $1 --snapshotname $DATE --metadata 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't delete $1 temporary snapshot: $err_msg"
		delete_temp_snapshot && exit 4
	fi
}

delete_temp_snapshot

function backup_config() {
	err_msg=`virsh dumpxml $1 > $BACKUP_DIR/$1/$DATE/$1.xml 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't create dump config $1: $err_msg"
		exit 5
	fi
}
