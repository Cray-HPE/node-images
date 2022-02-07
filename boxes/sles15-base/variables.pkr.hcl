variable "artifactory_user" {
  type = string
  default = ""
}

variable "artifactory_token" {
  type = string
  default = ""
}

variable "boot_wait" {
  type = string
  default = "10s"
}

variable "cpus" {
  type = string
  default = "2"
}

variable "disk_size" {
  type = string
  default = "42000"
}

variable "disk_cache" {
  type = string
  default = "unsafe"
}

variable "headless" {
  type = bool
  default = true
}

variable "image_name" {
  type = string
  default = "sles15-base"
}

variable "memory" {
  type = string
  default = "4096"
}

variable "source_iso_checksum" {
  type = string
  default = "938dd99becf3bf29d0948a52d04bcd1952ea72621a334f33ddb5e83909116b55"
}

variable "source_iso_uri" {
  type = string
  default = "iso/SLE-15-SP2-Full-x86_64-GM-Media1.iso"
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

variable "output_directory" {
  type = string
  default = "output-sles15-base"
}

variable "artifact_version" {
  type = string
  default = "none"
}

variable "create_kis_artifacts_arguments" {
  type = string
  default = "kernel-initrd-only"
}

variable "vbox_format" {
  type = string
  default = "ovf"
}

variable "qemu_accelerator" {
  type = string
  default = "kvm"
}

variable "qemu_format" {
  type = string
  default = "qcow2"
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

variable "google_destination_image_family" {
  type = string
  default = "vshasta-sles15-sp2"
}

variable "google_destination_project_network" {
  type = string
  default = "projects/shared-vpc-interconnect-202004/global/networks/default-network"
}
variable "google_subnetwork" {
  type = string
  default = "projects/shared-vpc-interconnect-202004/regions/us-central1/subnetworks/artifactory-subnet"
}
variable "google_zone" {
  type = string
  default = "us-central1-a"
}
variable "google_destination_project_id" {
  type = string
  default = "artifactory-202004"
}
