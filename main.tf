
# 配置阿里云 Provider
provider "alicloud" {
  region     = var. region
}

data "alicloud_zones" "default" {
  available_disk_category     = "cloud_essd"
  available_resource_creation = "VSwitch"
  available_instance_type     = var.instance_type
}

# 创建 ECS 实例（示例）
resource "alicloud_instance" "server" {
  instance_name        = var.instance_name
  instance_type        = var.instance_type
  image_id             = var.image_id
  system_disk_category = "cloud_essd"
  system_disk_size     = 40
  vswitch_id           = alicloud_vswitch.vsw.id
  security_groups      = alicloud_security_group.default.*.id
  password             = var.password
  internet_max_bandwidth_out = var.internet_bandwidth
  internet_charge_type       = "PayByTraffic"

  
  # 初始化脚本 - 安装基础依赖
  user_data = file("setup_docker.sh")
  
  tags = {
    Name        = var.instance_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


resource "alicloud_vpc" "vpc" {
  vpc_name   = var.instance_name
  cidr_block = "172.16.0.0/12"
}

resource "alicloud_vswitch" "vsw" {
  vpc_id     = alicloud_vpc.vpc.id
  cidr_block = "172.16.0.0/21"
  zone_id    = data.alicloud_zones.default.zones.0.id
}
resource "alicloud_security_group" "default" {
  name  = var.instance_name
  vpc_id = alicloud_vpc.vpc.id
}

resource "alicloud_security_group_rule" "allow_tcp_22" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = "0.0.0.0/0"
}

