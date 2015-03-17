#! /usr/bin/env bash

DATE=`date +%F`
DATA_DIR="/var/glusterfs/vm_images_and_config/images"
BACKUP_DIR="/snapshots"
LOG_PATH="/var/log/vm-backup.log"
NO_BACKUP="owncloud"

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

function not_backup() {
	echo $NO_BACKUP | egrep $VM 2>&1 1>/dev/null
	if [[ $? == 0 ]]; then
		log "$VM not backup"
		continue
	fi 
}

function get_disk() {
	log "get $VM disk"
	DISK=`virsh domblklist $VM | awk '/qcow2/ { print $1 }'`
}

function delete_temp_snapshot() {
	log "delete $VM temporary snapshot"
	rm -f $BACKUP_DIR/$VM-snapshot.qcow2 1>/dev/null 2>&1
}

# create snapshot
function create_temp_snapshot() {
	log "create $VM temporary snapshot"
	err_msg=`virsh snapshot-create-as --domain $VM $DATE --diskspec $DISK,file=$BACKUP_DIR/$VM-snapshot.qcow2 --disk-only --atomic 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Cant't create $VM temporary snapshot: $err_msg"
		delete_temp_snapshot && exit 1
	fi
}

function create_snapshot_dir() {
	if [[ ! -d $BACKUP_DIR/$VM/$DATE ]]; then
		log "create $VM backup dir"
		mkdir -p $BACKUP_DIR/$VM/$DATE
	fi
}

function backup_image() {
	log "backup $VM image"
	err_msg=`rsync -a $DATA_DIR/$VM.qcow2 $BACKUP_DIR/$VM/$DATE/$VM.qcow2 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't backup $VM image: $err_msg"
		delete_temp_snapshot && exit 2
	fi
}

function blockcommit_image() {
	log "blockcommit $VM image"
	err_msg=`virsh blockcommit $VM $DISK --active --verbose --pivot 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't do blockcommit $VM: $err_msg"
		delete_temp_snapshot && exit 3
	fi
}

function delete_snapshot() {
	log "delete $VM temporary snapshot"
	err_msg=`virsh snapshot-delete --domain $VM --snapshotname $DATE --metadata 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't delete $VM temporary snapshot: $err_msg"
		delete_temp_snapshot && exit 4
	fi
}

function backup_config() {
	log "backup $VM config"
	err_msg=`virsh dumpxml $VM > $BACKUP_DIR/$VM/$DATE/$VM.xml 2>&1 1>/dev/null`
	if [[ $? != 0 ]]; then
		error "Can't create dump config $VM: $err_msg"
		exit 5
	fi
}

# Go go go
get_vms
for VM in $VMS; do
	not_backup
	get_disk 
	create_temp_snapshot
	create_snapshot_dir
	backup_image 
	blockcommit_image 
	delete_snapshot 
	backup_config 
	delete_temp_snapshot 
done
