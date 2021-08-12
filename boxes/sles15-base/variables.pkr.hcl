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
  default = "2a6259fc849fef6ce6701b8505f64f89de0d2882857def1c9e4379d26e74fa56"
}

variable "source_iso_uri" {
  type = string
  default = "iso/SLE-15-SP3-Full-x86_64-GM-Media1.iso"
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
