NAME ?= cray-node-image-build
VERSION ?= $(shell cat .version)


all: prepare base
base: base_vbox base_qemu

prepare:
	echo "Hello, Jenkins!"

base_vbox:
	PACKER_LOG=1 packer build -only=virtualbox-ovf.sles15-base -var 'ssh_password="${SLES15_INITIAL_ROOT_PASSWORD}"' boxes/sles15-base/
base_qemu:
	PACKER_LOG=1 packer build -only=qemu.sles15-base -var 'ssh_password="${SLES15_INITIAL_ROOT_PASSWORD}"' boxes/sles15-base/
