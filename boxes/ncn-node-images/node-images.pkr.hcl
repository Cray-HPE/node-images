source "virtualbox-ovf" "kubernetes" {
  source_path = "${var.vbox_source_path}"
  format = "${var.vbox_format}"
  checksum = "none"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/kubernetes"
  output_filename = "${var.image_name_k8s}"
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
  guest_additions_mode = "disable"
}

source "virtualbox-ovf" "ceph" {
  source_path = "${var.vbox_source_path}"
  format = "${var.vbox_format}"
  checksum = "none"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/storage-ceph"
  output_filename = "${var.image_name_ceph}"
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
  guest_additions_mode = "disable"
}

source "qemu" "kubernetes" {
  accelerator = "${var.qemu_accelerator}"
  use_default_display = "${var.qemu_default_display}"
  display = "${var.qemu_display}"
  cpus = "${var.cpus}"
  disk_cache = "${var.disk_cache}"
  disk_size = "${var.disk_size}"
  memory = "${var.memory}"
  iso_checksum = "${var.source_iso_checksum}"
  iso_url = "${var.source_image_uri}"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/kubernetes"
  vm_name = "${var.image_name_k8s}.${var.qemu_format}"
  disk_image = true
  disk_discard = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression = true
  skip_compaction = false
  vnc_bind_address = "${var.vnc_bind_address}"
}

source "qemu" "storage-ceph" {
  accelerator = "${var.qemu_accelerator}"
  use_default_display = "${var.qemu_default_display}"
  display = "${var.qemu_display}"
  cpus = "${var.cpus}"
  disk_cache = "${var.disk_cache}"
  disk_size = "${var.disk_size}"
  memory = "${var.memory}"
  iso_url = "${var.source_image_uri}"
  iso_checksum = "none"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/storage-ceph"
  vm_name = "${var.image_name_ceph}.${var.qemu_format}"
  disk_image = true
  disk_discard = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression = true
  skip_compaction = false
  vnc_bind_address = "${var.vnc_bind_address}"
}

build {
  sources = [
    "source.virtualbox-ovf.kubernetes",
    "source.virtualbox-ovf.ceph",
    "source.qemu.kubernetes",
    "source.qemu.storage-ceph"
  ]

  provisioner "file" {
    source = "${path.root}k8s/files"
    destination = "/tmp/"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "file" {
    source = "${path.root}ceph/files"
    destination = "/tmp/"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph"]
  }

  provisioner "file" {
    source = "csm-rpms"
    destination = "/tmp/files/"
  }

  provisioner "file" {
    source = "custom"
    destination = "/tmp/files/"
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c 'if [ -f /root/zero.file ]; then rm /root/zero.file; fi'"]
  }

  provisioner "shell" {
    script = "${path.root}k8s/provisioners/common/setup.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}ceph/provisioners/common/setup.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph"]
  }

  provisioner "shell" {
    inline = [
      "sudo -E bash -c '. /srv/cray/scripts/common/build-functions.sh; setup-dns'"]
  }

  provisioner "shell" {
    environment_vars = [
      "CUSTOM_REPOS_FILE=${var.custom_repos_file}",
      "ARTIFACTORY_USER=${var.artifactory_user}",
      "ARTIFACTORY_TOKEN=${var.artifactory_token}"
    ]
    inline = ["bash -c /srv/cray/custom/repos.sh"]
  }

  provisioner "shell" {
    inline = [
      "sudo -E bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.packages explicit'",
      "sudo -E bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.deps.packages deps'"
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
      "qemu.storage-ceph"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/metal.packages'"]
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph"]
  }

  provisioner "shell" {
    script = "${path.root}k8s/provisioners/common/install.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}ceph/provisioners/common/install.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph"]
  }

  provisioner "shell" {
    script = "${path.root}k8s/provisioners/common/sdu/install.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}k8s/provisioners/metal/install.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}ceph/provisioners/metal/install.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph"]
  }

  provisioner "shell" {
    inline = [
      "sudo -E bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.packages explicit'",
      "sudo -E bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.deps.packages deps'",
      "sudo -E bash -c 'zypper lr -e /tmp/installed.repos'"
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
    destination = "${var.output_directory}/${source.name}/"
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/${source.name}/installed.repos"
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
    script = "${path.root}ceph/files/scripts/common/cleanup.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph"]
  }

  provisioner "shell" {
    script = "${path.root}k8s/files/scripts/common/cleanup.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '/srv/cray/scripts/common/create-kis-artifacts.sh'"]
    only = [
      "qemu.kubernetes",
      "qemu.storage-ceph"
    ]
  }
  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}/${source.name}/"
    only = [
      "qemu.kubernetes",
      "qemu.storage-ceph"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '/srv/cray/scripts/common/cleanup-kis-artifacts.sh'"]
    only = [
      "qemu.kubernetes",
      "qemu.storage-ceph"
    ]
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
      "qemu.storage-ceph"]
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
        "echo 'Extracting KIS artifacts package'",
        "echo 'Putting image name into the squashFS filename.'",
        "ls -lR ./${var.output_directory}/${source.name}",
        "tar -xzvf ${var.output_directory}/${source.name}/kis.tar.gz -C ${var.output_directory}/${source.name}",
        "mv ${var.output_directory}/${source.name}/filesystem.squashfs ${var.output_directory}/${source.name}/${source.name}.squashfs",
        "rm ${var.output_directory}/${source.name}/kis.tar.gz"
      ]
      only   = [
        "qemu.kubernetes",
        "qemu.storage-ceph"
      ]
    }
    post-processor "manifest" {
      output = "${var.output_directory}/${source.name}/manifest.json"
    }
#    post-processor "compress" {
#      output = "${var.output_directory}/${source.name}/${source.name}-${var.artifact_version}.tar.gz"
#      keep_input_artifact = true
#    }
  }
}