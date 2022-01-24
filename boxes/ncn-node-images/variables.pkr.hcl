variable "cpus" {
  type = string
  default = "2"
}

variable "disk_cache" {
  type = string
  default = "unsafe"
}

variable "disk_size" {
  type = string
  default = "42000"
}

variable "docker_image_registry" {
  type = string
  default = "artifactory.algol60.net/csm-docker/stable/docker.io"
}

variable "k8s_image_registry" {
  type = string
  default = "artifactory.algol60.net/csm-docker/stable/k8s.gcr.io"
}

variable "quay_image_registry" {
  type = string
  default = "artifactory.algol60.net/csm-docker/stable/quay.io"
}

variable "headless" {
  type = bool
  default = true
}

variable "image_name_k8s" {
  type = string
  default = "kubernetes"
}

variable "image_name_ceph" {
  type = string
  default = "storage-ceph"
}

variable "memory" {
  type = string
  default = "4096"
}

variable "ssh_password" {
  sensitive = true
  type = string
  default = null
}

variable "ssh_username" {
  type = string
  default = "root"
}

variable "ssh_wait_timeout" {
  type = string
  default = "10000s"
}

variable "source_iso_checksum" {
  type = string
  default = "none"
}

variable "source_iso_uri" {
  type = string
  default = "output-ncn-common/ncn-common.qcow2"
}

variable "vbox_source_path" {
  type = string
  default = "output-ncn-common/ncn-common.ovf"
}

variable "output_directory" {
  type = string
  default = "output-ncn-node-images"
}

variable "artifact_version" {
  type = string
  default = "none"
}

variable "qemu_accelerator" {
  type = string
  default = "kvm"
}

variable "qemu_format" {
  type = string
  default = "qcow2"
}

variable "vbox_format" {
  type = string
  default = "ovf"
}

variable "qemu_default_display" {
  type = bool
  default = true
}

variable "qemu_display" {
  type = string
  default = "none"
}

variable "qemu_disk_compression" {
  type = bool
  default = true
}

variable "qemu_skip_compaction" {
  type = bool
  default = false
}

variable "vnc_bind_address" {
  type = string
  default = "0.0.0.0"
}

variable "artifactory_user" {
  type = string
  default = ""
}

variable "artifactory_token" {
  type = string
  default = ""
}

variable "custom_repos_file" {
  type = string
  default = ""
}

variable "google_subnetwork" {
  type = string
  default = "artifactory-subnet"
}

variable "google_zone" {
  type = string
  default = "us-central1-a"
}

variable "google_destination_project_id" {
  type = string
  default = "artifactory-202004"
}

variable "google_network_project_id" {
  type = string
  default = "shared-vpc-interconnect-202004"
}

variable "google_service_account_email" {
  type = string
  default = "image-manager@artifactory-202004.iam.gserviceaccount.com"
}

variable "google_use_internal_ip" {
  type = bool
  default = true
}

variable "google_source_image_project_id" {
  type = list(string)
  default = ["artifactory-202004"]
}

variable "google_source_image_family" {
  type = string
  default = "vshasta-non-compute-common-rc"
}

variable "google_source_image_name" {
  type = string
  default = ""
}
variable "google_disk_size_gb" {
  type = string
  default = "150"
}
variable "google_source_image_url" {
  type = string
  default = ""
}

variable "build_url" {
  type = string
  default = ""
}
