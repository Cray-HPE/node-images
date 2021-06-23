source "virtualbox-ovf" "kubernetes" {
  source_path             = "output-sles15-images/k8s/sles15-vbox-k8s.ovf"
  checksum                = "none"
  shutdown_command        = "echo 'vagrant'|sudo -S /sbin/halt -h -p"
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
  source_path             = "output-sles15-images/ceph/sles15-vbox-ceph.ovf"
  checksum                = "none"
  shutdown_command        = "echo 'vagrant'|sudo -S /sbin/halt -h -p"
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

  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/setup-vagrant.sh"
    ]
  }

  post-processor "vagrant" {}

  post-processor "manifest" {
    output = "vagrant-manifest.json"
  }
}
