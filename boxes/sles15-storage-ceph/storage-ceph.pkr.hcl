source "virtualbox-ovf" "storage-ceph" {
  source_path             = "output-sles15-compute-common/sles15-compute-common.ovf"
  checksum                = "none"
  shutdown_command        = "echo 'vagrant'|sudo -S /sbin/halt -h -p"
  ssh_password            = "${var.ssh_password}"
  ssh_username            = "${var.ssh_username}"
  ssh_wait_timeout        = "10000s"
  output_directory        = "${var.output_directory}"
  output_filename         = "${var.image_name}"
  vboxmanage              = [
    ["modifyvm", "{{ .Name }}", "--memory", "${var.memory}"],
    ["modifyvm", "{{ .Name }}", "--cpus", "${var.cpus}"],
    [ "modifyvm", "{{ .Name }}",  "--firmware", "efi" ],
    [ "modifyvm", "{{ .Name }}", "--vram", "${var.vb_vram}" ]]
  virtualbox_version_file = ".vbox_version"
}

build {
  sources = ["source.virtualbox-ovf.storage-ceph"]

  provisioner "file" {
    source = "${path.root}/files"
    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c 'if [ -f /root/zero-file ]; then rm /root/zero-file; fi'"]
  }


  provisioner "shell" {
    script = "${path.root}/provisioners/common/setup.sh"
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/scripts/common/build-functions.sh; setup-dns'"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; set -e; setup-package-repos'"]
  }

  provisioner "shell" {
    inline = [
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.packages explicit'",
      "sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.deps.packages deps'"
    ]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/base.packages'"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/metal.packages'"]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/ses.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/install.sh"
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '/srv/cray/scripts/metal/set-dhcp-config.sh'"]
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
    destination = "${var.output_directory}"
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/installed.repos"
  }


  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-package-repos'"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/scripts/common/build-functions.sh; cleanup-dns'"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-all-repos'"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '/srv/cray/scripts/common/create-kis-artifacts.sh'"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}"
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '/srv/cray/scripts/common/cleanup-kis-artifacts.sh'"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '/srv/cray/scripts/metal/zeros.sh'"]
  }

  provisioner "shell" {
    script = "${path.root}/files/scripts/common/cleanup.sh"
  }

  post-processor "vagrant" {
    keep_input_artifact = true
    output = "${var.image_name}-{{ .Provider }}.box"
    provider_override = "virtualbox"
  }

  post-processor "manifest" {
    output = "ceph-storage-manifest.json"
  }

}