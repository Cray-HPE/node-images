source "virtualbox-ovf" "kubernetes" {
  source_path             = "output-sles15-base/sles15-base.ovf"
  checksum                = "none"
  headless                = "${var.headless}"
  shutdown_command        = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password            = "${var.ssh_password}"
  ssh_username            = "${var.ssh_username}"
  ssh_wait_timeout        = "10000s"
  output_directory        = "${var.output_directory}/k8s"
  output_filename         = "${var.image_name}-k8s"
  vboxmanage              = [
    [ "modifyvm", "{{ .Name }}", "--memory", "${var.memory}"],
    [ "modifyvm", "{{ .Name }}", "--cpus", "${var.cpus}"],
    [ "modifyvm", "{{ .Name }}",  "--firmware", "efi" ],
    [ "modifyvm", "{{ .Name }}", "--vram", "${var.vb_vram}" ]]
  virtualbox_version_file = ".vbox_version"
}

source "virtualbox-ovf" "ceph" {
  source_path             = "output-sles15-base/sles15-base.ovf"
  checksum                = "none"
  headless                = "${var.headless}"
  shutdown_command        = "echo '${var.ssh_password}'|sudo -S /sbin/halt -h -p"
  ssh_password            = "${var.ssh_password}"
  ssh_username            = "${var.ssh_username}"
  ssh_wait_timeout        = "10000s"
  output_directory        = "${var.output_directory}/ceph"
  output_filename         = "${var.image_name}-ceph"
  vboxmanage              = [
    [ "modifyvm", "{{ .Name }}", "--memory", "${var.memory}"],
    [ "modifyvm", "{{ .Name }}", "--cpus", "${var.cpus}"],
    [ "modifyvm", "{{ .Name }}",  "--firmware", "efi" ],
    [ "modifyvm", "{{ .Name }}", "--vram", "${var.vb_vram}" ]]
  virtualbox_version_file = ".vbox_version"
}

build {
  sources = ["source.virtualbox-ovf.kubernetes", "source.virtualbox-ovf.ceph"]

  provisioner "file" {
    source = "${path.root}/k8s/files"
    destination = "/tmp/"
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "file" {
    source = "${path.root}/ceph/files"
    destination = "/tmp/"
    only = ["virtualbox-ovf.ceph"]
  }


  provisioner "file" {
    source = "csm-rpms"
    destination = "/tmp/files/"
  }

  // Merge into common file area
  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/common/setup.sh"
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c 'if [ -f /root/zero.file ]; then rm /root/zero.file; fi'"]
  }

  //This does nothing on metal, specific to GCP
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
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-kubernetes/base.packages'"]
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-kubernetes/metal.packages'"]
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/base.packages'"]
    only = ["virtualbox-ovf.ceph"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/metal.packages'"]
    only = ["virtualbox-ovf.ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/common/install.sh"
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/ceph/provisioners/metal/ses.sh"
    only = ["virtualbox-ovf.ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/ceph/provisioners/common/install.sh"
    only = ["virtualbox-ovf.ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/common/sdu/install.sh"
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/provisioners/metal/install.sh"
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "shell" {
    script = "${path.root}/ceph/provisioners/metal/install.sh"
    only = ["virtualbox-ovf.ceph"]
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
    destination = "${var.output_directory}/k8s/"
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/k8s/installed.repos"
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "file" {
    direction = "download"
    sources = [
      "/tmp/initial.deps.packages",
      "/tmp/initial.packages",
      "/tmp/installed.deps.packages",
      "/tmp/installed.packages"
    ]
    destination = "${var.output_directory}/ceph/"
    only = ["virtualbox-ovf.ceph"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/ceph/installed.repos"
    only = ["virtualbox-ovf.ceph"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-package-repos'"]
  }

  //This does nothing on metal, specific to gcp
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
    destination = "${var.output_directory}/k8s/"
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}/ceph/"
    only = ["virtualbox-ovf.ceph"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '/srv/cray/scripts/common/cleanup-kis-artifacts.sh'"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '/srv/cray/scripts/common/zeros.sh'"]
    only = ["virtualbox-ovf.kubernetes"]
  }

  provisioner "shell" {
    inline = ["sudo -S bash -c '/srv/cray/scripts/metal/zeros.sh'"]
    only = ["virtualbox-ovf.ceph"]
  }

  provisioner "shell" {
    script = "${path.root}/k8s/files/scripts/common/cleanup.sh"
  }

  post-processor "manifest" {
    output = "node-images-manifest.json"
  }

}