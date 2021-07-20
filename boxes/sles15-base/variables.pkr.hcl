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
  default = "25000"
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

variable "create_kis_artifacts_arguments" {
  type = string
  default = "kernel-initrd-only"
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

variable "vnc_bind_address" {
  type = string
  default = "0.0.0.0"
}
