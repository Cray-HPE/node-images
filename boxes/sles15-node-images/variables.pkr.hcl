variable "cpus" {
  type    = string
  default = "2"
}

variable "disk_size" {
  type    = string
  default = "25000"
}

variable "headless" {
  type    = bool
  default = true
}

variable "image_name" {
  type    = string
  default = "sles15-vbox"
}

variable "memory" {
  type    = string
  default = "4096"
}

variable "ssh_password" {
  sensitive = true
  type = string
  default = null
}

variable "ssh_username" {
  type    = string
  default = "root"
}

variable "output_directory" {
  type    = string
  default = "output-sles15-images"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

locals {
  version = "${local.timestamp}"
}