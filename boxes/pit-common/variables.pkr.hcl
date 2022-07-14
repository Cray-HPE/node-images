#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
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
  default = "8000"
}

variable "headless" {
  type = bool
  default = true
}

variable "image_name" {
  type = string
  default = "pit-common"
}

variable "memory" {
  type = string
  default = "4096"
}

variable "vbox_source_path" {
  type = string
  default = "output-sles15-base/sles15-base.ovf"
}

variable "source_iso_checksum" {
  type = string
  default = "none"
}

variable "source_iso_uri" {
  type = string
  default = "output-sles15-base/sles15-base.qcow2"
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
  default = "output-pit-common"
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

variable "google_destination_image_family" {
  type = string
  default = "vshasta-pit-common-rc"
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
  default = "vshasta-sles15-base"
}

variable "google_source_image_name" {
  type = string
  default = ""
}
variable "google_disk_size_gb" {
  type = string
  default = "16"
}
variable "google_source_image_url" {
  type = string
  default = ""
}

variable "build_url" {
  type = string
  default = ""
}

variable "image_guest_os_features" {
  type = list(string)
  default = ["MULTI_IP_SUBNET"]
}

variable "pit_slug" {
  type = string
}
