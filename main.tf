terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.230.0"
    }
  }
}

provider "alicloud" {
  region = "cn-hangzhou"
}

# 创建 VPC
resource "alicloud_vpc" "main" {
  vpc_name    = "my-vpc"
  cidr_block  = "192.168.0.0/16"
  description = "My VPC for testing"
}

# 创建 VSwitch（交换机）
resource "alicloud_vswitch" "main" {
  vpc_id       = alicloud_vpc.main. id
  cidr_block   = "192.168.1.0/24"
  zone_id      = "cn-hangzhou-b"
  vswitch_name = "my-vswitch"
}

# 输出 VPC ID
output "vpc_id" {
  value = alicloud_vpc.main.id
}

output "vswitch_id" {
  value = alicloud_vswitch.main.id
}