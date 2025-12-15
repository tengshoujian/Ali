variable "instance_type" {
  type    = string
  default = "ecs.e-c1m2.large"
}

variable "image_id" {
  type    = string
  default = "ubuntu_18_04_64_20G_alibase_20190624.vhd"
}

variable "region" {
  type    = string
  default = "cn-huhehaote"
}

variable "internet_bandwidth" {
  type    = string
  default = "10"
}

variable "instance_name" {
  type    = string
  default = "tf-sample"
}

variable "password" {
  type    = string
  default = "Test@123456"
}

variable "ecs_count" {
  type    = number
  default = 1
}