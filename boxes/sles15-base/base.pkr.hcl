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
  format = "${var.vbox_format}"
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
  output_directory = "${var.output_directory}"
  output_filename = "${var.image_name}-${var.artifact_version}"
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
  use_default_display = "${var.qemu_default_display}"
  display = "${var.qemu_display}"
  format = "${var.qemu_format}"
  boot_wait = "${var.boot_wait}"
  cpus = "${var.cpus}"
  memory = "${var.memory}"
  disk_cache = "${var.disk_cache}"
  disk_size = "${var.disk_size}"
  disk_discard = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression = "${var.qemu_disk_compression}"
  skip_compaction = "${var.qemu_skip_compaction}"
  headless = "${var.headless}"
  http_directory = "${path.root}/http"
  iso_checksum = "${var.source_iso_checksum}"
  iso_url = "${var.source_iso_uri}"
  shutdown_command = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_port = 22
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}"
  vnc_bind_address = "${var.vnc_bind_address}"
  vm_name = "${var.image_name}-${var.artifact_version}.${var.qemu_format}"
}

build {
  sources = [
    "source.virtualbox-iso.sles15-base",
    "source.qemu.sles15-base"]

  provisioner "shell" {
    script = "${path.root}/scripts/wait-for-autoyast-completion.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "ARTIFACTORY_USER=${var.artifactory_user}",
      "ARTIFACTORY_TOKEN=${var.artifactory_token}"
    ]
    script = "${path.root}/scripts/kernel.sh"
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

  provisioner "shell" {
    script = "${path.root}/scripts/cleanup.sh"
  }

  provisioner "shell" {
    script = "${path.root}/scripts/google-grub.sh"
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
          "echo 'Saving variable file for use in google import'",
          "echo google_destination_project_id=\"${var.google_destination_project_id}\" > ./scripts/google/.variables",
          "echo output_directory=\"${var.output_directory}\" >> ./scripts/google/.variables",
          "echo image_name=\"${var.image_name}\" >> ./scripts/google/.variables",
          "echo version=\"${var.artifact_version}\" >> ./scripts/google/.variables",
          "echo qemu_format=\"${var.qemu_format}\" >> ./scripts/google/.variables",
          "echo google_destination_image_family=\"${var.google_destination_image_family}\" >> ./scripts/google/.variables",
          "echo google_network=\"${var.google_destination_project_network}\" >> ./scripts/google/.variables",
          "echo google_subnetwork=\"${var.google_subnetwork}\" >> ./scripts/google/.variables",
          "echo google_zone=\"${var.google_zone}\" >> ./scripts/google/.variables"
      ]
    }
  }
}
