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

# create snaapshot
err_msg=`virsh snapshot-create-as --domain $VM $DATE --diskspec $DISK,file=$BACKUP_DIR/$VM-snapshot.qcow2 --disk-only --atomic 2>&1 1>/dev/null`
if [[ $? != 0 ]]; then
	error "Cant't create $VM snapshot: $err_msg"
	delete_temp_snapshot && exit 1
fi

if [[ ! -d $BACKUP_DIR/$VM ]]; then
	mkdir $BACKUP_DIR/$VM
fi
if [[ ! -d $BACKUP_DIR/$VM/$DATE ]]; then
	mkdir $BACKUP_DIR/$VM/$DATE
fi

err_msg=`rsync -a $DATA_DIR/$VM.qcow2 $BACKUP_DIR/$VM/$DATE/$VM.qcow2 2>&1 1>/dev/null`
if [[ $? != 0 ]]; then
	error "Can't backup $VM image: $err_msg"
	delete_temp_snapshot && exit 2
fi

err_msg=`virsh blockcommit $VM $DISK --active --verbose --pivot 2>&1 1>/dev/null`
if [[ $? != 0 ]]; then
	error "Can't do blockcommit $VM: $err_msg"
	delete_temp_snapshot && exit 3
fi

err_msg=`virsh snapshot-delete --domain $VM --snapshotname $DATE --metadata 2>&1 1>/dev/null`
if [[ $? != 0 ]]; then
	error "Can't delete $VM temporary snapshot: $err_msg"
	delete_temp_snapshot && exit 4
fi
delete_temp_snapshot

err_msg=`virsh dumpxml $VM > $BACKUP_DIR/$VM/$DATE/$VM.xml 2>&1 1>/dev/null`
if [[ $? != 0 ]]; then
	error "Can't create dump config $VM: $err_msg"
	exit 5
fi
