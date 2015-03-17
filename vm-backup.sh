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
	log "find VM's"
	VMS=`virsh list --state-running --name`
	if [[ $? != 0 ]]; then
		log "VM's not found" && exit 0
	fi
}

function get_disk() {
	log "get $1 disk"
	DISK=`virsh domblklist $1 | awk '/qcow2/ { print $1 }'`
}

function delete_temp_snapshot() {
	log "delete $1 temporary snapshot"
	rm -f $BACKUP_DIR/$1-snapshot.qcow2 1>/dev/null 2>&1
}

# create snapshot
function create_temp_snapshot() {
	log "create $1 temporary snapshot"
	err_msg=`virsh snapshot-create-as --domain $1 $DATE --diskspec $DISK,file=$BACKUP_DIR/$1-snapshot.qcow2 --disk-only --atomic 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Cant't create $1 temporary snapshot: $err_msg"
		delete_temp_snapshot $1 && exit 1
	fi
}

function create_snapshot_dir() {
	if [[ ! -d $BACKUP_DIR/$1/$DATE ]]; then
		log "create $1 backup dir"
		mkdir -p $BACKUP_DIR/$1/$DATE
	fi
}

function backup_image() {
	log "backup $1 image"
	err_msg=`rsync -a $DATA_DIR/$1.qcow2 $BACKUP_DIR/$1/$DATE/$1.qcow2 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't backup $1 image: $err_msg"
		delete_temp_snapshot $1 && exit 2
	fi
}

function blockcommit_image() {
	log "blockcommit $1 image"
	err_msg=`virsh blockcommit $1 $DISK --active --verbose --pivot 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't do blockcommit $1: $err_msg"
		delete_temp_snapshot $1 && exit 3
	fi
}

function delete_snapshot() {
	log "delete $1 temporary snapshot"
	err_msg=`virsh snapshot-delete --domain $1 --snapshotname $DATE --metadata 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't delete $1 temporary snapshot: $err_msg"
		delete_temp_snapshot $1 && exit 4
	fi
}

function backup_config() {
	log "backup $1 config"
	err_msg=`virsh dumpxml $1 > $BACKUP_DIR/$1/$DATE/$1.xml 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't create dump config $1: $err_msg"
		exit 5
	fi
}

# Go go go
get_vms
for $VM in $VMS; do
	get_disk $VM
	create_temp_snapshot $VM
	create_snapshot_dir
	backup_image $VM
	blockcommit_image $VM
	delete_snapshot $VM
	backup_config $VM
	delete_temp_snapshot $VM
done
