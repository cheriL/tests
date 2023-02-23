#!/bin/bash
#
# test virtio blk devices hotplugging and direct volume.

set -e

PWD="${pwd}"

source "../../lib/common.bash"
source "../../metrics/lib/common.bash"

CONTAINER_NAME="${CONTAINER_NAME:-test}"
IMAGE="${IMAGE:-docker.io/library/busybox:latest}"

declare -A vol_xfs vol_ext
vol_xfs=([dst]="/mnt/fs_test" [size]="2G" [resize]="5G")
vol_ext=([dst]="/tmp" [size]="5G" [resize]="8G")

check_lo_dev() {
    #TODO
}
 
setup() {
    yum install -y qemu-img

    fs_type="xfs"
    loop_dev=$(sudo losetup -f)
    qemu-img create test_vol_xfs ${vol_xfs[size]}
    losetup $loop_dev test_vol_xfs
    mkfs -t $fs_type -f $loop_dev
    vol_xfs[src]=$loop_dev
    vol_xfs[mount_info]="{\"Device\": \"$loop_dev\", \"fstype\": \"$fs_type\", \"VolumeType\": \"block\"}"

    fs_type="ext4"
    loop_dev=$(sudo losetup -f)
    qemu-img create test_vol_ext ${vol_ext[size]}
    losetup $loop_dev test_vol_ext
    mkfs -t $fs_type -F $loop_dev
    vol_ext[src]=$loop_dev
    vol_ext[mount_info]="{\"Device\": \"$loop_dev\", \"fstype\": \"$fs_type\", \"VolumeType\": \"block\"}"
}

teardown() {
    clean_env_ctr
    check_processes
}

test() {
    kata-runtime direct-volume add --volume-path ${vol_xfs[src]} --mount-info "${vol_xfs[mount_info]}"
    kata-runtime direct-volume add --volume-path ${vol_ext[src]} --mount-info "${vol_ext[mount_info]}"

    sudo ctr image pull "${IMAGE}"
        [ $? != 0 ] && die "Unable to get image $IMAGE"
        sudo ctr run --runtime="${CTR_RUNTIME}" -d --rm  \
        --mount src=${vol_xfs[src]},dst=${vol_xfs[dst]},type=bind,options=rbind:rw \
        --mount src=${vol_ext[src]},dst=${vol_ext[dst]},type=bind,options=rbind:rw \
         "${IMAGE}" "${CONTAINER_NAME}" sh -c "tail -f /dev/null" || die "Test failed"

    ## test 'df -hT'
    xfs_mount=$(ctr t exec --exec-id test ${CONTAINER_NAME} sh -c 'df -hT | grep xfs' | awk '{print $7}')
    [ $xfs_mount == ${vol_xfs[dst]} ] || die "Test failed"
    ext_mount=$(ctr t exec --exec-id test ${CONTAINER_NAME} sh -c 'df -hT | grep ext' | awk '{print $7}')
    [ $ext_mount == ${vol_ext[dst]} ] || die "Test failed"

    ## test rw
    sudo ctr t exec --exec-id test ${CONTAINER_NAME} sh -c "echo test > ${vol_xfs[dst]}/test_file" || die "Test failed"
    sudo ctr t exec --exec-id test ${CONTAINER_NAME} sh -c "rm ${vol_xfs[dst]}/test_file" || die "Test failed"
    sudo ctr t exec --exec-id test ${CONTAINER_NAME} sh -c "echo test > ${vol_ext[dst]}/test_file" || die "Test failed"
    sudo ctr t exec --exec-id test ${CONTAINER_NAME} sh -c "rm ${vol_ext[dst]}/test_file" || die "Test failed"
}