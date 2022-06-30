source "virtualbox-ovf" "ncn-common" {
  source_path = "${var.vbox_source_path}"
  format = "${var.vbox_format}"
  checksum = "none"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}"
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
  guest_additions_mode = "disable"
}

source "qemu" "ncn-common" {
  accelerator = "${var.qemu_accelerator}"
  cpus = "${var.cpus}"
  disk_cache = "${var.disk_cache}"
  disk_discard = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression = "${var.qemu_disk_compression}"
  skip_compaction = "${var.qemu_skip_compaction}"
  disk_image = true
  disk_size = "${var.disk_size}"
  display = "${var.qemu_display}"
  use_default_display = "${var.qemu_default_display}"
  memory = "${var.memory}"
  headless = "${var.headless}"
  iso_checksum = "${var.source_iso_checksum}"
  iso_url = "${var.source_iso_uri}"
  shutdown_command = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}"
  vnc_bind_address = "${var.vnc_bind_address}"
  vm_name = "${var.image_name}.${var.qemu_format}"
  format = "${var.qemu_format}"
}

source "googlecompute" "ncn-common" {
  instance_name = "vshasta-${var.image_name}-builder-${var.artifact_version}"
  project_id = "${var.google_destination_project_id}"
  network_project_id = "${var.google_network_project_id}"
  source_image_project_id = "${var.google_source_image_project_id}"
  source_image_family = "${var.google_source_image_family}"
  source_image = "${var.google_source_image_name}"
  service_account_email = "${var.google_service_account_email}"
  ssh_username = "root"
  zone = "${var.google_zone}"
  image_family = "${var.google_destination_image_family}"
  image_name = "vshasta-${var.image_name}-${var.artifact_version}"
  image_description = "build.source-artifact = ${var.google_source_image_url}, build.url = ${var.build_url}"
  machine_type = "n2-standard-32"
  subnetwork = "${var.google_subnetwork}"
  disk_size = "${var.google_disk_size_gb}"
  use_internal_ip = "${var.google_use_internal_ip}"
  omit_external_ip = "${var.google_use_internal_ip}"
}

build {
  sources = [
    "source.virtualbox-ovf.ncn-common",
    "source.qemu.ncn-common",
    "source.googlecompute.ncn-common"]


  // Setup each context (e.g. common, google, and metal)
  // common/setup.sh expands disk and preps ansible environment
  provisioner "shell" {
    script = "${path.root}/provisioners/common/setup.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/google/setup.sh"
    only = ["googlecompute.ncn-common"]
  }

  // Run ansible for common and metal
  provisioner "ansible-local" {
    inventory_file  = "vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir    = "vendor/github.com/Cray-HPE/metal-provision"
    playbook_file   = "vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common_setup.yml"
    command         = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook -vv --tags common,metal"
    only = [
      "qemu.ncn-common",
      "virtualbox-ovf.ncn-common"
    ]
  }

  // Run ansible for common and gcp
  provisioner "ansible-local" {
    inventory_file  = "vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir    = "vendor/github.com/Cray-HPE/metal-provision"
    playbook_file   = "vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common_setup.yml"
    command         = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook -vv --tags common,gcp"
    only = ["googlecompute.ncn-common"]
  }

  provisioner "file" {
    source = "vendor/github.com/Cray-HPE/csm-rpms"
    destination = "/srv/cray/"
  }

  provisioner "shell" {
    environment_vars = [
      "CUSTOM_REPOS_FILE=${var.custom_repos_file}",
      "ARTIFACTORY_USER=${var.artifactory_user}",
      "ARTIFACTORY_TOKEN=${var.artifactory_token}"
    ]
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; setup-package-repos'"]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    environment_vars = [
      "CUSTOM_REPOS_FILE=${var.custom_repos_file}",
      "ARTIFACTORY_USER=${var.artifactory_user}",
      "ARTIFACTORY_TOKEN=${var.artifactory_token}"
    ]
    inline = ["bash -c /srv/cray/scripts/repos.sh"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.deps.packages deps'"
    ]
    only = [
      "qemu.ncn-common",
      "virtualbox-ovf.ncn-common"
    ]
  }

  // Install packages by context (e.g. base (a.k.a. common), google, or metal)
  # TODO: MTL-1513: Convert to ansible
  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-non-compute-common/base.packages'"]
    valid_exit_codes = [0, 123]
  }

  # TODO: MTL-1513: Convert to ansible
  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-non-compute-common/google.packages'"]
    valid_exit_codes = [0, 123]
    only = ["googlecompute.ncn-common"]
  }

  # TODO: MTL-1513: Convert to ansible
  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-non-compute-common/metal.packages'"]
    valid_exit_codes = [0, 123]
    only = ["qemu.ncn-common", "virtualbox-ovf.ncn-common"]
  }

  // Run ansible for common and metal
  provisioner "ansible-local" {
    inventory_file  = "vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir    = "vendor/github.com/Cray-HPE/metal-provision"
    playbook_file   = "vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common_install.yml"
    command         = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags common,metal"
    only = [
      "qemu.ncn-common",
      "virtualbox-ovf.ncn-common"
    ]
  }

  // Run ansible for common and gcp
  provisioner "ansible-local" {
    inventory_file  = "vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir    = "vendor/github.com/Cray-HPE/metal-provision"
    playbook_file   = "vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common_install.yml"
    command         = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags common,gcp"
    only = ["googlecompute.ncn-common"]
  }

  // Install all generic installers first by context (e.g. common, google, and metal).
  // Installs kernel and kernel modules
  provisioner "shell" {
    script = "${path.root}/provisioners/common/install.sh"
  }

  // Creates a virtualenv for GCP
  provisioner "shell" {
    script = "${path.root}/provisioners/google/install.sh"
    only = ["googlecompute.ncn-common"]

  }

  // Installs a package that needs to unlock the kernel
  provisioner "shell" {
    script = "${path.root}/provisioners/metal/install.sh"
    only = ["qemu.ncn-common", "virtualbox-ovf.ncn-common"]
  }

  // Run ansible for common and metal for team installers
  provisioner "ansible-local" {
    inventory_file  = "vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir    = "vendor/github.com/Cray-HPE/metal-provision"
    playbook_file   = "vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common_team.yml"
    command         = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags common"
  }

  # TODO: MTL-1513 Add another ansible playbook for csm/install.sh
  provisioner "shell" {
    script = "${path.root}/provisioners/metal/csm/install.sh"
    only = ["qemu.ncn-common", "virtualbox-ovf.ncn-common"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.deps.packages deps'",
      "bash -c 'zypper lr -e /tmp/installed.repos'"
    ]
    only = [
      "qemu.ncn-common",
      "virtualbox-ovf.ncn-common"
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
    destination = "${var.output_directory}/"
    only = [
      "qemu.ncn-common",
      "virtualbox-ovf.ncn-common"
    ]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/installed.repos"
    only = [
      "qemu.ncn-common",
      "virtualbox-ovf.ncn-common"
    ]
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
    script = "${path.root}/scripts/cleanup.sh"
  }

  provisioner "shell" {
    inline = [
      "bash -c '/srv/cray/scripts/common/create-kis-artifacts.sh ${var.create_kis_artifacts_arguments}'"]
    only = ["qemu.ncn-common"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '/srv/cray/scripts/common/cleanup-kis-artifacts.sh'"]
    only = ["qemu.ncn-common"]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/common/goss-image-common.yaml validate -f junit | tee /tmp/goss_out.xml'"]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/metal/goss-image-common.yaml validate -f junit | tee /tmp/goss_metal_out.xml'"]
    only = [
      "qemu.ncn-common",
      "virtualbox-ovf.ncn-common"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/google/goss-image-common.yaml validate -f junit | tee /tmp/goss_google_out.xml'"]
    only = ["googlecompute.ncn-common"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/goss_out.xml"
    destination = "${var.output_directory}/test-results.xml"
    only = [
      "qemu.ncn-common",
      "virtualbox-ovf.ncn-common"
    ]
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
        "if cat ${var.output_directory}/test-results.xml | grep '<failure>'; then echo 'Error: goss test failures found! See build output for details'; exit 1; fi"]
      only = ["qemu.ncn-common"]
    }
  }
}
