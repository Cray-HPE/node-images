variable "cpus" {
  type = string
  default = "2"
}

variable "headless" {
  type = bool
  default = true
}

variable "image_name" {
  type = string
  default = "ncn-vagrant"
}

variable "memory" {
  type = string
  default = "4096"
}

variable "ssh_wait_timeout" {
  type = string
  default = "10000s"
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

variable "artifact_version" {
  type = string
  default = "none"
}

variable "output_directory" {
  type = string
  default = "output-ncn-vagrant"
}