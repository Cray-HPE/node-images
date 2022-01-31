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

source "virtualbox-ovf" "storage-ceph" {
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
  iso_url = "${var.source_iso_uri}"
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
  iso_url = "${var.source_iso_uri}"
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

source "googlecompute" "kubernetes" {
  instance_name = "vshasta-${var.image_name_k8s}-builder-${var.artifact_version}"
  project_id = "${var.google_destination_project_id}"
  network_project_id = "${var.google_network_project_id}"
  source_image_project_id = "${var.google_source_image_project_id}"
  source_image_family = "${var.google_source_image_family}"
  source_image = "${var.google_source_image_name}"
  service_account_email = "${var.google_service_account_email}"
  ssh_username = "root"
  zone = "${var.google_zone}"
  image_family = "vshasta-kubernetes-rc"
  image_name = "vshasta-${var.image_name_k8s}-${var.artifact_version}"
  image_description = "build.source-artifact = ${var.google_source_image_url}, build.url = ${var.build_url}"
  machine_type = "n2-standard-8"
  subnetwork = "${var.google_subnetwork}"
  disk_size = "${var.google_disk_size_gb}"
  use_internal_ip = "${var.google_use_internal_ip}"
  omit_external_ip = "${var.google_use_internal_ip}"
}

source "googlecompute" "storage-ceph" {
  instance_name = "vshasta-${var.image_name_ceph}-builder-${var.artifact_version}"
  project_id = "${var.google_destination_project_id}"
  network_project_id = "${var.google_network_project_id}"
  source_image_project_id = "${var.google_source_image_project_id}"
  source_image_family = "${var.google_source_image_family}"
  source_image = "${var.google_source_image_name}"
  service_account_email = "${var.google_service_account_email}"
  ssh_username = "root"
  zone = "${var.google_zone}"
  image_family = "vshasta-storage-ceph-rc"
  image_name = "vshasta-${var.image_name_ceph}-${var.artifact_version}"
  image_description = "build.source-artifact = ${var.google_source_image_url}, build.url = ${var.build_url}"
  machine_type = "n2-standard-8"
  subnetwork = "${var.google_subnetwork}"
  disk_size = "${var.google_disk_size_gb}"
  use_internal_ip = "${var.google_use_internal_ip}"
  omit_external_ip = "${var.google_use_internal_ip}"
}

build {
  sources = [
    "source.virtualbox-ovf.kubernetes",
    "source.virtualbox-ovf.storage-ceph",
    "source.qemu.kubernetes",
    "source.qemu.storage-ceph",
    "source.googlecompute.kubernetes",
    "source.googlecompute.storage-ceph"
  ]

  provisioner "file" {
    source = "${path.root}/k8s/files"
    destination = "/tmp/"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes",
      "googlecompute.kubernetes"]
  }

  provisioner "file" {
    source = "${path.root}/storage-ceph/files"
    destination = "/tmp/"
    only = [
      "virtualbox-ovf.storage-ceph",
      "qemu.storage-ceph",
      "googlecompute.storage-ceph"]
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
      "bash -c 'if [ -f /root/zero.file ]; then rm /root/zero.file; fi'"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/common/setup.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes",
      "googlecompute.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/storage-ceph/provisioners/common/setup.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph",
      "googlecompute.storage-ceph"]
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
    except = [
      "googlecompute.kubernetes",
      "googlecompute.storage-ceph"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-kubernetes/base.packages'"]
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes",
      "googlecompute.kubernetes"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-kubernetes/metal.packages'"]
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-kubernetes/google.packages'"]
    only = ["googlecompute.kubernetes"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/base.packages'"]
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph",
      "googlecompute.storage-ceph"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/metal.packages'"]
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph"]
  }

  provisioner "shell" {
    environment_vars = [
      "DOCKER_IMAGE_REGISTRY=${var.docker_image_registry}",
      "K8S_IMAGE_REGISTRY=${var.k8s_image_registry}",
      "QUAY_IMAGE_REGISTRY=${var.quay_image_registry}"
    ]
    script = "${path.root}/k8s/provisioners/common/install.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes",
      "googlecompute.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/storage-ceph/provisioners/common/install.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph",
      "googlecompute.storage-ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/common/sdu/install.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes",
      "googlecompute.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/metal/install.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/storage-ceph/provisioners/metal/install.sh"
    only = [
      "virtualbox-ovf.ceph",
      "qemu.storage-ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/google/install.sh"
    only = ["googlecompute.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/storage-ceph/provisioners/google/install.sh"
    only = ["googlecompute.storage-ceph"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.deps.packages deps'",
      "bash -c 'zypper lr -e /tmp/installed.repos'"
    ]
    only = [
      "virtualbox-ovf.kubernetes",
      "virtualbox-ovf.storage-ceph",
      "qemu.kubernetes",
      "qemu.storage-ceph"]
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
    only = [
      "virtualbox-ovf.kubernetes",
      "virtualbox-ovf.storage-ceph",
      "qemu.kubernetes",
      "qemu.storage-ceph"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/${source.name}/installed.repos"
    only = [
      "virtualbox-ovf.kubernetes",
      "virtualbox-ovf.storage-ceph",
      "qemu.kubernetes",
      "qemu.storage-ceph"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-package-repos'"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-all-repos'"]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/cleanup.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/cleanup.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes",
      "virtualbox-ovf.storage-ceph",
      "qemu.storage-ceph"
    ]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/google/cleanup.sh"
    only = [
      "googlecompute.kubernetes",
      "googlecompute.storage-ceph"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c '/srv/cray/scripts/common/create-kis-artifacts.sh'"]
    only = [
      "qemu.kubernetes",
      "qemu.storage-ceph"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/common/goss-image-common.yaml validate -f junit | tee /tmp/goss_out.xml'"]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/metal/goss-image-common.yaml validate -f junit | tee /tmp/goss_metal_out.xml'"]
    except = [
      "googlecompute.kubernetes",
      "googlecompute.storage-ceph"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/google/goss-image-common.yaml validate -f junit | tee /tmp/goss_google_out.xml'"]
    only = [
      "googlecompute.kubernetes",
      "googlecompute.storage-ceph"
    ]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/goss_out.xml"
    destination = "${var.output_directory}/${source.name}/test-results.xml"
    except = [
      "googlecompute.kubernetes",
      "googlecompute.storage-ceph"
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
      "bash -c '/srv/cray/scripts/common/cleanup-kis-artifacts.sh'"]
    only = [
      "qemu.kubernetes",
      "qemu.storage-ceph"
    ]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/zeros.sh"
    only = [
      "virtualbox-ovf.kubernetes",
      "qemu.kubernetes",
      "virtualbox-ovf.storage-ceph",
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
    post-processor "shell-local" {
      inline = [
        "if cat ${var.output_directory}/${source.name}/test-results.xml | grep '<failure>'; then echo 'Error: goss test failures found! See build output for details'; exit 1; fi"
      ]
      only   = [
        "qemu.kubernetes",
        "qemu.storage-ceph"
      ]
    }
  }
}
