# -*- coding: utf-8; mode: makefile-gmake; -*-
# https://gitlab.com/tvaughan/windows-vm

MAKEFLAGS += --warn-undefined-variables

SHELL := bash
.SHELLFLAGS := $(or ${SHELLFLAGS},${SHELLFLAGS},-euo pipefail -c)

HERE := $(shell cd -P -- $(shell dirname -- $$0) && pwd -P)

.PHONY: all
all: run-compile

export LATESTURL := $(shell curl -is https://aka.ms/windev_VM_virtualbox | grep ^Location | cut -d' ' -f2)
export VMVERSION := $(shell basename $(LATESTURL) | cut -d'.' -f1)
export VMPACKAGE := $(HOME)/Downloads/$(VMVERSION)

VMPREFIX ?= windows-vm

export VMNAME := "$(VMPREFIX) - $(VMVERSION)"

.PHONY: check-downloads
check-downloads:
	@cd Shared/Downloads && md5sum --quiet -c MD5SUMS

$(VMPACKAGE).zip:
	@curl -o $(VMPACKAGE).zip $(LATESTURL)

.PHONY: download-zip
download-zip: $(VMPACKAGE).zip

$(VMPACKAGE).ova: $(VMPACKAGE).zip
	@unzip -d $(shell dirname $(VMPACKAGE).zip) $(VMPACKAGE).zip
	@touch $(VMPACKAGE).ova

.PHONY: extract-ova
extract-ova: $(VMPACKAGE).ova

.PHONY: import-ova
import-ova: $(VMPACKAGE).ova
	@if ! VBoxManage list vms | grep -cq $(VMNAME);				\
	then									\
	    VBoxManage import $(VMPACKAGE).ova					\
	      --vsys 0								\
	      --vmname $(VMNAME)						\
	      --ostype Windows10_64						\
	      --cpus 2								\
	      --memory 2048							\
	      --eula accept;							\
	fi

.PHONY: delete-port-forward-rules
delete-port-forward-rules:
	@if ! VBoxManage list runningvms | grep -cq $(VMNAME);			\
	then									\
	    IFS=$$'\n\t';							\
	    for RULE in $$(VBoxManage showvminfo $(VMNAME) --machinereadable	\
	      | grep ^Forwarding | awk -F '[",]' '{ print $$2; }');		\
	    do									\
	        VBoxManage modifyvm $(VMNAME) --natpf1 delete "$$RULE";		\
	    done;								\
	fi

.PHONY: set-port-forward-rules
set-port-forward-rules: import-ova delete-port-forward-rules
	@if ! VBoxManage list runningvms | grep -cq $(VMNAME);			\
	then									\
	    VBoxManage modifyvm $(VMNAME) --natpf1 "openssh,tcp,,9022,,22";	\
	fi

.PHONY: delete-shared-folder-mappings
delete-shared-folder-mappings:
	@if ! VBoxManage list runningvms | grep -cq $(VMNAME);			\
	then									\
	    IFS=$$'\n\t';							\
	    for MAPPING in $$(VBoxManage showvminfo $(VMNAME) --machinereadable	\
	      | grep ^SharedFolderNameMachineMapping | awk -F '[",]' '{ print $$2; }');	\
	    do									\
	        VBoxManage sharedfolder remove $(VMNAME) --name "$$MAPPING";	\
	    done;								\
	fi

.PHONY: set-shared-folder-mappings
set-shared-folder-mappings: import-ova delete-shared-folder-mappings
	@if ! VBoxManage list runningvms | grep -cq $(VMNAME);			\
	then									\
	    for RELPATH in $(HERE)/Shared;					\
	    do									\
	        ABSPATH=$$(readlink -f "$$RELPATH");				\
	        VBoxManage sharedfolder add $(VMNAME)				\
	          --name $$(basename $$ABSPATH)					\
	          --automount							\
	          --hostpath $$ABSPATH;						\
	    done;								\
	fi

.PHONY: vm-name
vm-name:
	@echo $(VMNAME)

.PHONY: vm-status
vm-status:
	@VBoxManage showvminfo $(VMNAME) --machinereadable			\
	  | grep ^VMState= | awk -F '[",]' '{ print $$2; }'

.PHONY: vm-create
vm-create: check-downloads set-port-forward-rules set-shared-folder-mappings

.PHONY: vm-start
vm-start: vm-create
	@if ! VBoxManage list runningvms | grep -cq $(VMNAME);			\
	then									\
	    VBoxManage startvm $(VMNAME) --type headless;			\
	fi

.PHONY: vm-shutdown
vm-shutdown:
	@if VBoxManage list runningvms | grep -cq $(VMNAME);			\
	then									\
	    VBoxManage controlvm $(VMNAME) poweroff;				\
	fi

.PHONY: run-%
run-%: vm-start
	@docker pull registry.gitlab.com/tvaughan/docker-ubuntu:18.04 > /dev/null
	@docker run --rm -it							\
	    -v "$(PWD)":/mnt/workdir						\
	    registry.gitlab.com/tvaughan/docker-ubuntu:18.04			\
	    sshpass								\
	    -p password								\
	    ssh									\
	    -o StrictHostKeyChecking=no						\
	    -p 9022								\
	    User@host.docker.internal						\
	    "Z:\$*.bat"								\
	    #
