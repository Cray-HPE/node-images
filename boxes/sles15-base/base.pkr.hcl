source "virtualbox-iso" "sles15-base" {
  boot_command            = [
    "<esc><enter><wait>",
    "linux netdevice=eth0 netsetup=dhcp install=cd:/<wait>",
    " lang=en_US autoyast=http://{{ .HTTPIP }}:{{ .HTTPPort }}/autoinst.xml<wait>",
    " textmode=1 password=${var.ssh_password}<wait>",
    "<enter><wait>"
  ]
  boot_wait               = "10s"
  cpus                    = "${var.cpus}"
  memory                  = "${var.memory}"
  disk_size               = "${var.disk_size}"
  guest_additions_path    = "VBoxGuestAdditions_{{ .Version }}.iso"
  guest_os_type           = "OpenSUSE_64"
  hard_drive_interface    = "sata"
  http_directory          = "${path.root}/http"
  iso_checksum            = "${var.source_iso_checksum}"
  iso_url                 = "${var.source_iso_uri}"
  sata_port_count         = 8
  shutdown_command        = "echo 'vagrant'|sudo -S /sbin/halt -h -p"
  ssh_password            = "${var.ssh_password}"
  ssh_port                = 22
  ssh_username            = "${var.ssh_username}"
  ssh_wait_timeout        = "10000s"
  output_directory        = "output-sles15-base"
  output_filename         = "sles15-base"
  vboxmanage              = [
      [ "modifyvm", "{{ .Name }}", "--memory", "${var.memory}" ],
      [ "modifyvm", "{{ .Name }}", "--cpus", "${var.cpus}" ]
    ]
  virtualbox_version_file = ".vbox_version"
}

build {
  sources = ["source.virtualbox-iso.sles15-base"]

  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/wait-for-autoyast-completion.sh",
      "${path.root}/scripts/setup.sh",
      "${path.root}/scripts/postinstall.sh",
      "${path.root}/scripts/virtualbox.sh",
      "${path.root}/scripts/remove-repos.sh",
      "${path.root}/scripts/cleanup.sh"
    ]
  }

  post-processor "vagrant" {
    keep_input_artifact = true
    output = "${var.image_name}-{{ .Provider }}.box"
    provider_override = "virtualbox"
  }

  post-processor "manifest" {
    output = "base-manifest.json"
  }
}
