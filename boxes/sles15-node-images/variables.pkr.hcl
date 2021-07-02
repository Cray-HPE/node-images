variable "cpus" {
  type = string
  default = "2"
}

variable "disk_size" {
  type = string
  default = "25000"
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

variable "output_directory" {
  type = string
  default = "output-sles15-images"
}

variable "qemu_accelerator" {
  type = string
  default = "kvm"
}

variable "qemu_format" {
  type = string
  default = "qcow2"
}

variable "qemu_display" {
  type = string
  default = "none"
}

variable "vnc_bind_address" {
  type = string
  default = "0.0.0.0"
}
