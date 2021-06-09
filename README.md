# Dependencies

## Software
- packer
- virtualbox
- vagrant

## SLES 15 SP2 ISO
You will need to obtain a copy of the SLES 15 SP2 ISO. The file name is `SLE-15-SP2-Full-x86_64-GM-Media1.iso`.
Copy this file into the `iso` directory.

# Build Steps

## Base Box
* Install packer from [here](https://www.packer.io/downloads.html)
* Ensure that `SLE-15-SP2-Full-x86_64-GM-Media1.iso` is in the iso folder
* Run `packer build -var 'ssh_password=something' boxes/sles15-base-virtualbox/`

The output will create a box `sles15-base-virtualbox.box` that can be loaded into Vagrant.

`# vagrant box add --force --name sles15sp2 ./sles15-base-virtualbox.box`

## Common Box
In the previous step a VirtualBox image was created in `output-sles15-base`. The sles15-compute-common stage is
configured to build on top of that. 
* Check out `csm-rpms` repository
  `cd boxes/sles15-compute-common/files`
  Run `ln -s ../../../../csm-rpms/ csm-rpms`
  Run `packer build -var 'ssh_password=something' boxes/sles15-compute-common/`
