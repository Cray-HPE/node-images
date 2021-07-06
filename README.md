# Dependencies

## Software
- packer
- qemu  
- virtualbox
- vagrant

## SLES 15 SP2 ISO
You will need to obtain a copy of the SLES 15 SP2 ISO. The file name is `SLE-15-SP2-Full-x86_64-GM-Media1.iso`.
Copy this file into the `iso` directory.

# Build Steps
* Install packer from [here](https://www.packer.io/downloads.html)

If you are building QEMU images in MacOS, you will need to adjust specific QEMU options:
* MacOS requires HVF for acceleration
* MacOS uses Cocoa for output
* Run `packer build -only=qemu.sles15-base -force -var 'ssh_password=something' -var 'headless=false' -var 'qemu_display=cocoa' -var 'qemu_accelerator=hvf' boxes/sles15-base/`

## Base Box

### Prerequisites
* Ensure that `SLE-15-SP2-Full-x86_64-GM-Media1.iso` is in the iso folder
* Check out `csm-rpms` repository and create a symlink to it in the root directory of the project.
* `cd node-image-build`
* Run `ln -s ../csm-rpms/ csm-rpms`

### Build

## Base Images
The base box will install SLES 15 SP2 and prepare the image for the installation of Kubernetes and Ceph.

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
The sles15-node-images stage builds on top of that to create functional images for Kubernetes and Ceph.

### Prerequisites
N/A
  
### Build
Execute the following command from the top level of the project
* Run `packer build -force -var 'ssh_password=something' boxes/sles15-node-images/`

To only build VirtualBox, run the following command.
* Run `packer build -only=virtualbox-ovf.* -force -var 'ssh_password=something' boxes/sles15-node-images/`

To only build QEMU, run the following command.
* Run `packer build -only=qemu.* -force -var 'ssh_password=something' boxes/sles15-node-images/`

If you want to view the output of the build, disable `headless` mode:
* Run `packer build -force -var 'ssh_password=something' -var 'headless=false' boxes/sles15-node-images/`

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

`# vagrant box add --force --name sles15sp2 ./sles15-base-virtualbox.box`