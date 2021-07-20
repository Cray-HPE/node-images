source "virtualbox-ovf" "kubernetes" {
  source_path = "output-sles15-common/vbox/sles15-common.ovf"
  checksum = "none"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/vbox/k8s"
  output_filename = "${var.image_name}-k8s"
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
      "${var.cpus}"]]
  virtualbox_version_file = ".vbox_version"
}

source "virtualbox-ovf" "ceph" {
  source_path = "output-sles15-common/vbox/sles15-common.ovf"
  checksum = "none"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/vbox/ceph"
  output_filename = "${var.image_name}-ceph"
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
      "${var.cpus}"]]
  virtualbox_version_file = ".vbox_version"
}

source "qemu" "kubernetes" {
  accelerator = "${var.qemu_accelerator}"
  use_default_display = "${var.qemu_default_display}"
  display = "${var.qemu_display}"
  cpus = "${var.cpus}"
  disk_cache = "${var.disk_cache}"
  memory = "${var.memory}"
  iso_checksum = "${var.source_iso_checksum}"
  iso_url = "${var.source_iso_uri}"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/qemu/k8s"
  vm_name = "${var.image_name}.${var.qemu_format}-k8s"
  disk_image = true
  disk_discard = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression = true
  skip_compaction = false
  skip_compaction = true
  vnc_bind_address = "${var.vnc_bind_address}"
}

source "qemu" "ceph" {
  accelerator = "${var.qemu_accelerator}"
  use_default_display = "${var.qemu_default_display}"
  display = "${var.qemu_display}"
  cpus = "${var.cpus}"
  disk_cache = "${var.disk_cache}"
  memory = "${var.memory}"
  iso_url = "${var.source_iso_uri}"
  iso_checksum = "none"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/qemu/ceph"
  vm_name = "${var.image_name}.${var.qemu_format}-ceph"
  disk_image = true
  disk_discard = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression = true
  skip_compaction = false
  skip_compaction = true
  vnc_bind_address = "${var.vnc_bind_address}"
}

build {
  sources = [
    "source.virtualbox-ovf.kubernetes",
    "source.virtualbox-ovf.ceph",
    "source.qemu.kubernetes",
    "source.qemu.ceph"
  ]

  provisioner "file" {
    source = "${path.root}/k8s/files"
    destination = "/tmp/"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "file" {
    source = "${path.root}/ceph/files"
    destination = "/tmp/"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.ceph"]
  }

  provisioner "file" {
    source = "csm-rpms"
    destination = "/tmp/files/"
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c 'if [ -f /root/zero.file ]; then rm /root/zero.file; fi'"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/common/setup.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/ceph/provisioners/common/setup.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.ceph"]
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
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-kubernetes/base.packages'"]
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-kubernetes/metal.packages'"]
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/base.packages'"]
    only = [
      "virtualbox-ovf.ceph",
      "qemu.ceph"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/metal.packages'"]
    only = [
      "virtualbox-ovf.ceph",
      "qemu.ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/common/install.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/ceph/provisioners/metal/ses.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/ceph/provisioners/common/install.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/common/sdu/install.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/metal/install.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/ceph/provisioners/metal/install.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.ceph"]
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
    destination = "${var.output_directory}/vbox/k8s/"
    only = [
      "virtualbox-ovf.kubernetes"]
  }

  provisioner "file" {
    direction = "download"
    sources = [
      "/tmp/initial.deps.packages",
      "/tmp/initial.packages",
      "/tmp/installed.deps.packages",
      "/tmp/installed.packages"
    ]
    destination = "${var.output_directory}/qemu/k8s/"
    only = [
      "qemu.kubernetes"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/vbox/k8s/installed.repos"
    only = [
      "virtualbox-ovf.kubernetes"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/qemu/k8s/installed.repos"
    only = [
      "qemu.kubernetes"]
  }

  provisioner "file" {
    direction = "download"
    sources = [
      "/tmp/initial.deps.packages",
      "/tmp/initial.packages",
      "/tmp/installed.deps.packages",
      "/tmp/installed.packages"
    ]
    destination = "${var.output_directory}/vbox/ceph/"
    only = [
      "virtualbox-ovf.ceph"]
  }

  provisioner "file" {
    direction = "download"
    sources = [
      "/tmp/initial.deps.packages",
      "/tmp/initial.packages",
      "/tmp/installed.deps.packages",
      "/tmp/installed.packages"
    ]
    destination = "${var.output_directory}/qemu/ceph/"
    only = [
      "qemu.ceph"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/vbox/ceph/installed.repos"
    only = [
      "virtualbox-ovf.ceph"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/qemu/ceph/installed.repos"
    only = [
      "qemu.ceph"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-package-repos'"]
  }

  //This does nothing on metal, specific to gcp
  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/scripts/common/build-functions.sh; cleanup-dns'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-all-repos'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '/srv/cray/scripts/common/create-kis-artifacts.sh'"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}/vbox/k8s/"
    only = [
      "virtualbox-ovf.kubernetes"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}/qemu/k8s/"
    only = [
      "qemu.kubernetes"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}/vbox/ceph/"
    only = [
      "virtualbox-ovf.ceph"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}/qemu/ceph/"
    only = [
      "qemu.ceph"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '/srv/cray/scripts/common/cleanup-kis-artifacts.sh'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '/srv/cray/scripts/common/zeros.sh'"]
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '/srv/cray/scripts/metal/zeros.sh'"]
    only = [
      "virtualbox-ovf.ceph",
      "qemu.ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/ceph/files/scripts/common/cleanup.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/files/scripts/common/cleanup.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'Extracting KIS artifacts package'",
      "tar -xzvf ${var.output_directory}/qemu/ceph/kis.tar.gz -C ${var.output_directory}/qemu/ceph/",
      "rm ${var.output_directory}/qemu/ceph/kis.tar.gz",
      "mv ${var.output_directory}/qemu/ceph/filesystem.squashfs ${var.output_directory}/qemu/ceph/${var.image_name}-ceph.squashfs"]
    only = [
      "qemu.ceph"]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'Extracting KIS artifacts package'",
      "tar -xzvf ${var.output_directory}/qemu/k8s/kis.tar.gz -C ${var.output_directory}/qemu/k8s/",
      "rm ${var.output_directory}/qemu/k8s/kis.tar.gz",
      "mv ${var.output_directory}/qemu/k8s/filesystem.squashfs ${var.output_directory}/qemu/k8s/${var.image_name}-k8s.squashfs"]
    only = [
      "qemu.kubernetes"]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'Extracting KIS artifacts package'",
      "tar -xzvf ${var.output_directory}/vbox/ceph/kis.tar.gz -C ${var.output_directory}/vbox/ceph/",
      "rm ${var.output_directory}/vbox/ceph/kis.tar.gz",
      "mv ${var.output_directory}/vbox/ceph/filesystem.squashfs ${var.output_directory}/vbox/ceph/${var.image_name}-ceph.squashfs"]
    only = [
      "vbox.ceph"]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'Extracting KIS artifacts package'",
      "tar -xzvf ${var.output_directory}/vbox/k8s/kis.tar.gz -C ${var.output_directory}/vbox/k8s/",
      "rm ${var.output_directory}/vbox/k8s/kis.tar.gz",
      "mv ${var.output_directory}/vbox/k8s/filesystem.squashfs ${var.output_directory}/vbox/k8s/${var.image_name}-k8s.squashfs"]
    only = [
      "vbox.kubernetes"]
  }

  post-processor "manifest" {
    output = "${var.output_directory}/manifest.json"
  }

}