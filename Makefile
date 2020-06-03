# -*- coding: utf-8; mode: makefile-gmake; -*-
# https://gitlab.com/tvaughan/windows-vm

MAKEFLAGS += --warn-undefined-variables

SHELL := bash
.SHELLFLAGS := $(or ${SHELLFLAGS},${SHELLFLAGS},-euo pipefail -c)

HERE := $(shell cd -P -- $(shell dirname -- $$0) && pwd -P)

.PHONY: all
all: run-compile

export LATESTURL := $(shell curl -is https://aka.ms/windev_VM_virtualbox | grep ^Location | cut -d' ' -f2)
export WINDOWS_VM_VERSION := $(shell basename $(LATESTURL) | cut -d'.' -f1)
export WINDOWS_VM_ARCHIVE := $(HOME)/Downloads/$(WINDOWS_VM_VERSION)

WINDOWS_VM_PREFIX ?= windows-vm

export WINDOWS_VM_NAME := "$(WINDOWS_VM_PREFIX) - $(WINDOWS_VM_VERSION)"

.PHONY: check-downloads
check-downloads:
	@cd Shared/Downloads && md5sum --quiet -c MD5SUMS

$(WINDOWS_VM_ARCHIVE).zip:
	@curl -o $(WINDOWS_VM_ARCHIVE).zip $(LATESTURL)

.PHONY: download-zip
download-zip: $(WINDOWS_VM_ARCHIVE).zip

$(WINDOWS_VM_ARCHIVE).ova: $(WINDOWS_VM_ARCHIVE).zip
	@unzip -d $(shell dirname $(WINDOWS_VM_ARCHIVE).zip) $(WINDOWS_VM_ARCHIVE).zip
	@touch $(WINDOWS_VM_ARCHIVE).ova

.PHONY: extract-ova
extract-ova: $(WINDOWS_VM_ARCHIVE).ova

.PHONY: import-ova
import-ova: $(WINDOWS_VM_ARCHIVE).ova
	@if ! VBoxManage list vms | grep -cq $(WINDOWS_VM_NAME);                \
	then                                                                    \
	    VBoxManage import $(WINDOWS_VM_ARCHIVE).ova                         \
	      --vsys 0                                                          \
	      --vmname $(WINDOWS_VM_NAME)                                       \
	      --ostype Windows10_64                                             \
	      --cpus 2                                                          \
	      --memory 2048                                                     \
	      --eula accept;                                                    \
	fi

.PHONY: delete-port-forward-rules
delete-port-forward-rules:
	@if ! VBoxManage list runningvms | grep -cq $(WINDOWS_VM_NAME);                         \
	then                                                                                    \
	    IFS=$$'\n\t';                                                                       \
	    for RULE in $$(VBoxManage showvminfo $(WINDOWS_VM_NAME) --machinereadable           \
	      | grep ^Forwarding | awk -F '[",]' '{ print $$2; }');                             \
	    do                                                                                  \
	        VBoxManage modifyvm $(WINDOWS_VM_NAME) --natpf1 delete "$$RULE";                \
	    done;                                                                               \
	fi

.PHONY: set-port-forward-rules
set-port-forward-rules: import-ova delete-port-forward-rules
	@if ! VBoxManage list runningvms | grep -cq $(WINDOWS_VM_NAME);                         \
	then                                                                                    \
	    VBoxManage modifyvm $(WINDOWS_VM_NAME) --natpf1 "openssh,tcp,,9022,,22";            \
	fi

.PHONY: delete-shared-folder-mappings
delete-shared-folder-mappings:
	@if ! VBoxManage list runningvms | grep -cq $(WINDOWS_VM_NAME);                         \
	then                                                                                    \
	    IFS=$$'\n\t';                                                                       \
	    for MAPPING in $$(VBoxManage showvminfo $(WINDOWS_VM_NAME) --machinereadable        \
	      | grep ^SharedFolderNameMachineMapping | awk -F '[",]' '{ print $$2; }');         \
	    do                                                                                  \
	        VBoxManage sharedfolder remove $(WINDOWS_VM_NAME) --name "$$MAPPING";           \
	    done;                                                                               \
	fi

.PHONY: set-shared-folder-mappings
set-shared-folder-mappings: import-ova delete-shared-folder-mappings
	@if ! VBoxManage list runningvms | grep -cq $(WINDOWS_VM_NAME);         \
	then                                                                    \
	    for RELPATH in $(HERE)/Shared;                                      \
	    do                                                                  \
	        ABSPATH=$$(readlink -f "$$RELPATH");                            \
	        VBoxManage sharedfolder add $(WINDOWS_VM_NAME)                  \
	          --name $$(basename $$ABSPATH)                                 \
	          --automount                                                   \
	          --hostpath $$ABSPATH;                                         \
	    done;                                                               \
	fi

.PHONY: vm-name
vm-name:
	@echo $(WINDOWS_VM_NAME)

.PHONY: vm-status
vm-status:
	@VBoxManage showvminfo $(WINDOWS_VM_NAME) --machinereadable             \
	  | grep ^VMState= | awk -F '[",]' '{ print $$2; }'

.PHONY: vm-create
vm-create: check-downloads set-port-forward-rules set-shared-folder-mappings

.PHONY: vm-start
vm-start: vm-create
	@if ! VBoxManage list runningvms | grep -cq $(WINDOWS_VM_NAME);         \
	then                                                                    \
	    VBoxManage startvm $(WINDOWS_VM_NAME) --type headless;              \
	fi

.PHONY: vm-shutdown
vm-shutdown:
	@if VBoxManage list runningvms | grep -cq $(WINDOWS_VM_NAME);           \
	then                                                                    \
	    VBoxManage controlvm $(WINDOWS_VM_NAME) poweroff;                   \
	fi

.PHONY: pull-latest
pull-latest:
	@docker pull registry.gitlab.com/tvaughan/docker-ubuntu:18.04 > /dev/null

.PHONY: vm-shell
vm-shell: pull-latest vm-start
	@docker run --rm -it                                                    \
	    -v "$(PWD)":/mnt/workdir                                            \
	    registry.gitlab.com/tvaughan/docker-ubuntu:18.04                    \
	    sshpass                                                             \
	    -p password1!                                                       \
	    ssh                                                                 \
	    -o StrictHostKeyChecking=no                                         \
	    -p 9022                                                             \
	    User@host.docker.internal                                           \
	    #

.PHONY: run-%
run-%: pull-latest vm-start
	@docker run --rm -it                                                    \
	    -v "$(PWD)":/mnt/workdir                                            \
	    registry.gitlab.com/tvaughan/docker-ubuntu:18.04                    \
	    sshpass                                                             \
	    -p password1!                                                       \
	    ssh                                                                 \
	    -o StrictHostKeyChecking=no                                         \
	    -p 9022                                                             \
	    User@host.docker.internal                                           \
	    "Z:\$*.bat"                                                         \
	    #
