variable "compartment_ocid" {
  type = string
}

variable "name" {
  type = string
}

variable "vcn_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.20.0.0/24"
}

variable "tags" {
  type    = map(string)
  default = {}
}
