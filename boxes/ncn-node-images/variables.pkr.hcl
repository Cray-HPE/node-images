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

variable "headless" {
  type = bool
  default = true
}

variable "image_name" {
  type = string
  default = "sles15-vbox"
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
  default = "output-sles15-images"
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