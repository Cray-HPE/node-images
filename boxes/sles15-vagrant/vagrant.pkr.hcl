source "virtualbox-ovf" "kubernetes" {
  source_path = "output-ncn-images/kubernetes/sles15-vbox.ovf"
  checksum = "none"
  shutdown_command = "echo 'vagrant'|/sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/kubernetes"
  output_filename = "${var.image_name}-kubernetes"
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
  source_path = "output-ncn-images/storage-ceph/sles15-vbox.ovf"
  checksum = "none"
  shutdown_command = "echo 'vagrant'|/sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/storage-ceph"
  output_filename = "${var.image_name}-storage-ceph"
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

build {
  sources = [
    "source.virtualbox-ovf.kubernetes",
    "source.virtualbox-ovf.storage-ceph"]

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
