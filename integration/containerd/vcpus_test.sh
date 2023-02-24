#!/bin/bash
#
# Copyright (c) 2020-2021 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#
# This will test the default_vcpus
# feature is working properly

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

dir_path=$(dirname "$0")
source "${dir_path}/../../lib/common.bash"
source "${dir_path}/../../.ci/lib.sh"

KATA_HYPERVISOR="${KATA_HYPERVISOR:-qemu}"
CONTAINER_NAME="${CONTAINER_NAME:-test}"
IMAGE="${IMAGE:-docker.io/library/busybox:latest}"

kata_config="/usr/share/defaults/kata-containers/configuration.toml"

function test_ctr_with_vcpus() {
	sudo ctr image pull "${IMAGE}"
	[ $? != 0 ] && die "Unable to get image $IMAGE"
	sudo ctr run --runtime="${CTR_RUNTIME}" -d "${IMAGE}" \
		"${CONTAINER_NAME}" sh -c "tail -f /dev/null" || die "Test failed"

	default_vcpus=$(cat $kata_config | grep "default_vcpus = " | awk '{print $3}')
    default_maxvcpus=$(cat $kata_config | grep -E "^default_maxvcpus = " | awk '{print $3}')
    [ $default_maxvcpus == 0 ] && default_maxvcpus=$(cat /proc/cpuinfo | grep "processor" | wc -l)
    echo "Default parameters: vcpu[${default_vcpus}] maxvcpu[${default_maxvcpus}]"

	qemu_process=$(ps aux | grep "sandbox-${CONTAINER_NAME}" | grep -v grep)
    temp=${qemu_process#*\-smp } && [ ${temp:0:${#default_vcpus}} == default_vcpus ] || die "error setting the default vcpu parameters"
    temp=${qemu_process#*maxcpus= } && [ ${temp:0:${#default_maxvcpus}} == default_vcpus ] || die "error setting the default max vcpu parameters"

	sudo sed -i "s/default_vcpus = 1/default_vcpus = 2/g" "$kata_config"
	sudo sed -i "s/default_maxvcpus = 0/default_maxvcpus = 8/g" "$kata_config"

	CONTAINER_1="${CONTAINER_NAME}-1"
	sudo ctr run --runtime="${CTR_RUNTIME}" -d "${IMAGE}" \
		"${CONTAINER_1}" sh -c "tail -f /dev/null" || die "Test failed"

	qemu_process=$(ps aux | grep "sandbox-${CONTAINER_NAME}" | grep -v grep)
    temp=${qemu_process#*\-smp } && [ ${temp:0:1} == 2 ] || die "error setting the default vcpu parameters"
    temp=${qemu_process#*maxcpus= } && [ ${temp:0:1} == 8 ] || die "error setting the default max vcpu parameters"
}

function teardown() {
	echo "Running teardown"
	sudo sed -i "s/default_vcpus = 2/default_vcpus = 1/g" "$kata_config"
	sudo sed -i "s/default_maxvcpus = 8/default_maxvcpus = 0/g" "$kata_config"

	clean_env_ctr
	check_processes
}

trap teardown EXIT

echo "Running ctr integration tests with vcpus"
test_ctr_with_vcpus
