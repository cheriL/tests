#/bin/bash

set -e

PWD="${pwd}"

source "../../lib/common.bash"
source "../../metrics/lib/common.bash"

CONTAINER_NAME="${CONTAINER_NAME:-test}"
IMAGE="${IMAGE:-docker.io/library/busybox:latest}"

readonly kata_config="/usr/share/defaults/kata-containers/configuration.toml"

test() {
    #check_msg=$(sudo kata-runtime check)

    sudo ctr image pull "${IMAGE}"
        [ $? != 0 ] && die "Unable to get image $IMAGE"
        sudo ctr run --runtime="${CTR_RUNTIME}" -d --rm "${IMAGE}" "${CONTAINER_NAME}" sh -c "tail -f /dev/null" || die "Test failed"

    ## agent pid
    agent_pid=$(sudo ctr t exec --exec-id test ${CONTAINER_NAME} sh -c 'ps -ef | grep init | grep -v grep' | awk '{print $1}')
    [ "$agent_pid" == 1 ] || die "the agent's pid $agent_pid is not pid1"
	
	## cpu, memory validation
    default_memory=$(cat $kata_config | grep "default_memory = " | awk '{print $3}')
    default_vcpus=$(cat $kata_config | grep "default_vcpus = " | awk '{print $3}')
    default_maxvcpus=$(cat $kata_config | grep -E "^default_maxvcpus = " | awk '{print $3}')
    [ $default_maxvcpus == 0 ] && default_maxvcpus=$(cat /proc/cpuinfo | grep "processor" | wc -l)
    echo "Default parameters: memory[${default_memory}] vcpu[${default_vcpus}] maxvcpu[${default_maxvcpus}]"

    qemu_process=$(ps aux | grep "sandbox-${CONTAINER_NAME}" | grep -v grep)
    temp=${qemu_process#*\-m } && [ ${temp:0:${#default_memory}} == default_memory ] || die "error setting the default memory parameters"
    temp=${qemu_process#*\-smp } && [ ${temp:0:${#default_vcpus}} == default_vcpus ] || die "error setting the default vcpu parameters"
    temp=${qemu_process#*\maxcpus= } && [ ${temp:0:${#default_maxvcpus}} == default_vcpus ] || die "error setting the default max vcpu parameters"
}

teardown() {
    clean_env_ctr
    check_processes
}

trap teardown EXIT

check_processes

test