#
# Copyright (c) 2017-2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

ifneq (,$(wildcard /usr/lib/os-release))
include /usr/lib/os-release
else
include /etc/os-release
endif

# The time limit in seconds for each test
TIMEOUT := 120

# union for 'make test'
UNION := kubernetes

# get arch
ARCH := $(shell bash -c '.ci/kata-arch.sh -d')

ARCH_DIR = arch
ARCH_FILE_SUFFIX = -options.mk
ARCH_FILE = $(ARCH_DIR)/$(ARCH)$(ARCH_FILE_SUFFIX)

INSTALL_FILES := $(wildcard .ci/install_*.sh)
INSTALL_TARGETS := $(INSTALL_FILES:.ci/install_%.sh=install-%)

# Load architecture-dependent settings
ifneq ($(wildcard $(ARCH_FILE)),)
include $(ARCH_FILE)
endif

# ksm:
# 	bash -f integration/ksm/ksm_test.sh

kubernetes:
	bash -f .ci/install_bats.sh
	bash -f integration/kubernetes/run_kubernetes_tests.sh

# nydus:
# 	bash -f integration/nydus/nydus_tests.sh

kubernetes-e2e:
	cd "integration/kubernetes/e2e_conformance" &&\
	cat skipped_tests_e2e.yaml &&\
	bash ./setup.sh &&\
	bash ./run.sh

# sandbox-cgroup:
# 	bash -f integration/sandbox_cgroup/sandbox_cgroup_test.sh

# stability:
# 	cd integration/stability && \
# 	ITERATIONS=2 MAX_CONTAINERS=20 ./soak_parallel_rm.sh
# 	cd integration/stability && ./hypervisor_stability_kill_test.sh

cri-containerd:
	bash integration/containerd/ctr_tests.sh

vcpus:
	bash -f integration/containerd/vcpus_test.sh

blk-volume:
	bash -f integration/containerd/volume_test.sh

test: ${UNION}

# $(INSTALL_TARGETS): install-%: .ci/install_%.sh
# 	@bash -f $<

# list-install-targets:
# 	@echo $(INSTALL_TARGETS) | tr " " "\n"

# rootless:
# 	bash -f integration/rootless/rootless_test.sh

# vfio:
# #	Skip: Issue: https://github.com/kata-containers/kata-containers/issues/1488
# #	bash -f functional/vfio/run.sh -s false -p clh -i image
# #	bash -f functional/vfio/run.sh -s true -p clh -i image
# 	bash -f functional/vfio/run.sh -s false -p qemu -m q35 -i image
# 	bash -f functional/vfio/run.sh -s true -p qemu -m q35 -i image

# agent: bash -f integration/agent/agent_test.sh

# monitor:
# 	bash -f functional/kata-monitor/run.sh

# PHONY in alphabetical order
.PHONY: \
	kubernetes \
	cri-containerd \
	vcpus \
	blk-volume
