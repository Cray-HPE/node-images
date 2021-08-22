# CRAY-Shasta Image Build Framework

This repository contains the [Packer][1] pipepline code for building CRAY High-Performance Computing as a Service (HPCaaS)
images for any distributable medium.

This page will suffice for getting started, but for more background information please see the official documentation in the [node-image-docs][2] repository.

# Getting Started

The listed software below will equip a local machine or buildserver to build for any medium (`.squashfs`, `.vbox`, `.qcow2`, `.iso`, etc.).

## Necessary Software
- media (`.iso` or `.qcow2`) (depending on the layer)
- packer
- qemu  
- vagrant
- virtualbox


### Media

Packer can intake any ISO, the sections below detail utilized base ISOs in CRAY HPCaaS.

For any ISO, copy it into the `iso` directory.

##### SuSE Linux Enterprise

The file name is `SLE-15-SP3-Full-x86_64-GM-Media1.iso`.

##### RHEL/CentOS

_Coming soon ..._ (?)

## Build Steps
* Install packer from a reputable endpoint, like **[this one][3]**.

If you are building QEMU images in MacOS, you will need to adjust specific QEMU options:
* MacOS requires HVF for acceleration
* MacOS uses Cocoa for output
* Run `packer build -only=qemu.sles15-base -force -var 'ssh_password=something' -var 'headless=false' -var 'qemu_display=cocoa' -var 'qemu_accelerator=hvf' boxes/sles15-base/`

## Base Box

### Prerequisites
* Ensure that `SLE-15-SP3-Full-x86_64-GM-Media1.iso` is in the iso folder
* Check out `csm-rpms` repository and create a symlink to it in the root directory of the project.
* `cd node-image-build`
* Run `ln -s ../csm-rpms/ csm-rpms`

### Build

## Base Images
The base box will install SLES 15 SP3 and prepare the image for the installation of Kubernetes and Ceph.

### Prerequisites
N/A

### Build
The `packer build` command will create both VirtualBox and QEMU versions of the base image.
Execute the following command from the top level of the project to build both.
* Run `packer build -force -var 'ssh_password=something' boxes/sles15-base/`
  
To only build VirtualBox, run the following command.
* Run `packer build -only=virtualbox-iso.sles15-base -force -var 'ssh_password=something' boxes/sles15-base/`
  
To only build QEMU, run the following command.
* Run `packer build -only=qemu.sles15-base -force -var 'ssh_password=something' boxes/sles15-base/`

If you want to view the output of the build, disable `headless` mode:
* Run `packer build -force -var 'ssh_password=something' -var 'headless=false' boxes/sles15-base/`

Once the images are built, the output will be placed in the `output-sles15-base` directory in the root of the project.

## Node Images

In the previous step a VirtualBox image, Qemu image, or both were created in `output-sles15-base`.
The ncn-node-images stage builds on top of that to create functional images for Kubernetes and Ceph.

### Prerequisites
N/A
  
### Build
Execute the following command from the top level of the project
* Run `packer build -force -var 'ssh_password=something' boxes/ncn-node-images/`

To only build VirtualBox, run the following command.
* Run `packer build -only=virtualbox-ovf.* -force -var 'ssh_password=something' boxes/ncn-node-images/`

To only build QEMU, run the following command.
* Run `packer build -only=qemu.* -force -var 'ssh_password=something' boxes/ncn-node-images/`

If you want to view the output of the build, disable `headless` mode:
* Run `packer build -force -var 'ssh_password=something' -var 'headless=false' boxes/ncn-node-images/`

Once the images are built, the output will be placed in the `output-sles15-images` directory in the root of the project.

## Vagrant
Vagrant boxes are only configured to build from the output of the VirtualBox builds. In order to create Vagrant boxes
you will first need to create the base image and the relevant node-image for Kubernetes and Ceph.

To build vagrant boxes, run the following command:
* Run `packer build -force -var 'ssh_password=something' boxes/sles15-vagrant/`

If you only want to build Kubernetes or Ceph, limit the build:
* Run `packer build -only=virtualbox-ovf.kubernetes -force -var 'ssh_password=something' boxes/sles15-vagrant/`


If you want to view the output of the build, disable `headless` mode:
* Run `packer build -force -var 'ssh_password=something' -var 'headless=false' boxes/sles15-vagrant/`

`# vagrant box add --force --name sles15sp3 ./sles15-base-virtualbox.box`

# Build Process

## Build Output
- There are two Providers that can be built; VirtualBox and QEMU
- VirtualBox is best for local development and carries the ability to create a Vagrant box.
- QEMU is best for pipeline and portability on linux machines. 
- Both outputs are capable of creating the kernel, initrd, and squashfs required to boot nodes.

## Versioning
- The version of the build is passed with the `packer build` command as a var:
```
packer build -only=qemu.* -force -var "artifact_version=`git rev-parse --short HEAD`" -var 'ssh_password=initial0' -var 'headless=false' -var 'qemu_display=cocoa' -var 'qemu_accelerator=hvf' boxes/sles15-base/
```
- If no version is passed to the builder then the version `none` is used when generating the archive.

## Base OS
- `boxes/sles15-base`
- The base OS is essentially unchanging unless something fundamental needs to be changed, such as partitions,
  filesystems, boot loaders, core users, kernels, qemu/vbox drivers, etc.
- The base OS should be built once and everything else should be built on top of it. 
- Base OS install requires the full media offline version of SLES 15 SP3

## Common layer
- `boxes/ncn-common`
- There are some common aspects to building the OS, but the ramp up and ramp downtime of this layer probably doesn't
  warrant keeping it separate.
- The common layer starts from the output of the base layer.
  
## Node image layers
- `boxes/ncn-node-images`
- The node image layers of `storage-ceph` and `kubernetes` are built here.

[1]: https://www.packer.io/
[2]: https://github.com/Cray-HPE/node-image-docs
[3]: https://www.packer.io/downloads.html