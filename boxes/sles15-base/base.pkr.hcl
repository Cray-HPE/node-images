source "virtualbox-iso" "sles15-base" {
  boot_command = [
    "<esc><enter><wait>",
    "linux netdevice=eth0 netsetup=dhcp install=cd:/<wait>",
    " lang=en_US autoyast=http://{{ .HTTPIP }}:{{ .HTTPPort }}/autoinst.xml<wait>",
    " textmode=1 password=${var.ssh_password}<wait>",
    "<enter><wait>"
  ]
  boot_wait = "${var.boot_wait}"
  cpus = "${var.cpus}"
  memory = "${var.memory}"
  disk_size = "${var.disk_size}"
  guest_additions_path = "VBoxGuestAdditions_{{ .Version }}.iso"
  guest_os_type = "OpenSUSE_64"
  hard_drive_interface = "sata"
  headless = "${var.headless}"
  http_directory = "${path.root}/http"
  iso_checksum = "${var.source_iso_checksum}"
  iso_url = "${var.source_iso_uri}"
  sata_port_count = 8
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_port = 22
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/vbox"
  output_filename = "${var.image_name}"
  vboxmanage = [
    [
      "modifyvm",
      "{{ .Name }}",
      "--memory",
      "${var.memory}"],
    [
      "modifyvm",
      "{{ .Name }}",
      "--cpus",
      "${var.cpus}"]
  ]
  virtualbox_version_file = ".vbox_version"
}

source "qemu" "sles15-base" {
  boot_command = [
    "<esc><enter><wait>",
    "linux netdevice=eth0 netsetup=dhcp install=cd:/<wait>",
    " lang=en_US autoyast=http://{{ .HTTPIP }}:{{ .HTTPPort }}/autoinst.xml<wait>",
    " textmode=1 password=${var.ssh_password}<wait>",
    "<enter><wait>"
  ]
  accelerator = "${var.qemu_accelerator}"
  display = "${var.qemu_display}"
  format = "${var.qemu_format}"
  boot_wait = "${var.boot_wait}"
  cpus = "${var.cpus}"
  memory = "${var.memory}"
  disk_size = "${var.disk_size}"
  disk_discard = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression = true
  skip_compaction = false
  headless = false
  http_directory = "${path.root}/http"
  iso_checksum = "${var.source_iso_checksum}"
  iso_url = "${var.source_iso_uri}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_port = 22
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/qemu"
  vnc_bind_address = "${var.vnc_bind_address}"
  vm_name = "${var.image_name}.${var.qemu_format}"
}

build {
  sources = [
    "source.virtualbox-iso.sles15-base",
    "source.qemu.sles15-base"]

  provisioner "shell" {
    script = "${path.root}/scripts/wait-for-autoyast-completion.sh"
  }

  provisioner "shell" {
    script = "${path.root}/scripts/virtualbox.sh"
    only = [
      "virtualbox-iso.sles15-base"]
  }

  provisioner "shell" {
    script = "${path.root}/scripts/qemu.sh"
    only = [
      "qemu.sles15-base"]
  }

  provisioner "file" {
    source = "${path.root}/files"
    destination = "/tmp/"
  }

  provisioner "file" {
    source = "csm-rpms"
    destination = "/tmp/files/"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/remove-repos.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/setup.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/setup.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/scripts/common/build-functions.sh; setup-dns'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; set -e; setup-package-repos'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.packages explicit'",
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.deps.packages deps'"
    ]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/hpc.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-non-compute-common/base.packages'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-non-compute-common/metal.packages'"]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/csm-testing/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/csm/cloud-init.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/fstab.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/python_symlink.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/cms/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/cos/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/cos/rsyslog.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/slingshot/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/kernel/modules.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '/srv/cray/scripts/common/create-kis-artifacts.sh ${var.create_kis_artifacts_arguments}'"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}/vbox/"
    only = [
      "virtualbox-iso.sles15-base"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}/qemu/"
    only = [
      "qemu.sles15-base"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '/srv/cray/scripts/common/cleanup-kis-artifacts.sh'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.packages explicit'",
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.deps.packages deps'",
      "sudo -S bash -c 'zypper lr -e /tmp/installed.repos'"
    ]
  }

  provisioner "file" {
    direction = "download"
    sources = [
      "/tmp/initial.deps.packages",
      "/tmp/initial.packages",
      "/tmp/installed.deps.packages",
      "/tmp/installed.packages"
    ]
    destination = "${var.output_directory}/vbox/"
    only = [
      "virtualbox-iso.sles15-base"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/vbox/installed.repos"
    only = [
      "virtualbox-iso.sles15-base"]
  }

  provisioner "file" {
    direction = "download"
    sources = [
      "/tmp/initial.deps.packages",
      "/tmp/initial.packages",
      "/tmp/installed.deps.packages",
      "/tmp/installed.packages"
    ]
    destination = "${var.output_directory}/qemu/"
    only = [
      "qemu.sles15-base"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/qemu/installed.repos"
    only = [
      "qemu.sles15-base"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-package-repos'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/scripts/common/build-functions.sh; cleanup-dns'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c 'goss -g /srv/cray/tests/common/goss-image-common.yaml validate -f junit | tee /tmp/goss_out.xml'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c 'goss -g /srv/cray/tests/metal/goss-image-common.yaml validate -f junit | tee /tmp/goss_metal_out.xml'"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/goss_out.xml"
    destination = "${var.output_directory}/vbox/test_results_{{ build_name }}.xml"
    only = [
      "virtualbox-iso.sles15-base"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/goss_out.xml"
    destination = "${var.output_directory}/qemu/test_results_{{ build_name }}.xml"
    only = [
      "qemu.sles15-base"]
  }

  provisioner "shell" {
    script = "${path.root}/files/scripts/common/cleanup.sh"
  }

  post-processor "manifest" {
    output = "base-manifest.json"
  }
}
