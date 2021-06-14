# Dependencies

## Software
- packer
- virtualbox
- vagrant

## SLES 15 SP2 ISO
You will need to obtain a copy of the SLES 15 SP2 ISO. The file name is `SLE-15-SP2-Full-x86_64-GM-Media1.iso`.
Copy this file into the `iso` directory.

# Build Steps
* Install packer from [here](https://www.packer.io/downloads.html)

## Base Box

### Prerequisites
* Ensure that `SLE-15-SP2-Full-x86_64-GM-Media1.iso` is in the iso folder
* Run `packer build -var 'ssh_password=something' boxes/sles15-base-virtualbox/`

The output will create a box `sles15-base-virtualbox.box` that can be loaded into Vagrant.

### Build
`# vagrant box add --force --name sles15sp2 ./sles15-base-virtualbox.box`

## Common Box
In the previous step a VirtualBox image was created in `output-sles15-base`. The sles15-compute-common stage is
configured to build on top of that.

### Prerequisites
* Check out `csm-rpms` repository and create a symlink to it in the `files` directory
* `cd boxes/sles15-compute-common/files`
* Run `ln -s ../../../../csm-rpms/ csm-rpms`

### Build
Execute the following command from the top level of the project
* Run `packer build -var 'ssh_password=something' boxes/sles15-compute-common/`

## Kubernetes Box
In the previous step a VirtualBox image was created in `output-sles15-compute-common`. The sles15-kubernetes stage is
configured to build on top of that. 

### Prerequisites
* Check out `csm-rpms` repository and create a symlink to it in the `files` directory
* `cd boxes/sles15-kubernetes/files`
* Run `ln -s ../../../../csm-rpms/ csm-rpms`
  
### Build
Execute the following command from the top level of the project
* Run `packer build -var 'ssh_password=something' boxes/sles15-kubernetes/`