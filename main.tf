provider "alicloud" {
  region = "cn-hangzhou"
}

# 创建 VPC
resource "alicloud_vpc" "main" {
  name       = "my-vpc"
  cidr_block = "192.168.0.0/16"
}

# 创建 VSwitch
resource "alicloud_vswitch" "main" {
  vpc_id            = alicloud_vpc.main.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "cn-hangzhou-b"
  name              = "my-vswitch"
}

# 创建安全组
resource "alicloud_security_group" "main" {
  name   = "my-security-group"
  vpc_id = alicloud_vpc.main.id
}

# 添加 SSH 规则
resource "alicloud_security_group_rule" "allow_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group. main.id
  cidr_ip           = "0.0.0.0/0"
}

# 创建 ECS 实例
resource "alicloud_instance" "default" {
  # 必需参数
  instance_type  = "ecs. t5-lc2m1.nano"
  image_id       = "ubuntu_20_04_x64_20G_alibase_20230618.vhd"
  security_groups = [alicloud_security_group.main.id]
  vswitch_id     = alicloud_vswitch.main.id
  
  # 可选参数
  instance_name              = "my-instance"
  internet_max_bandwidth_out = 10
  allocate_public_ip         = true
  password                   = "YourPassword123!"
  
  # 你的可选参数
  enable_jumbo_frame    = false
  deletion_protection   = false
  system_disk_encrypted = false
  force_delete          = false
  dry_run               = false
  maintenance_notify    = false
  include_data_disks    = true
  is_outdated           = false
  period_unit           = "Month"
  renewal_status        = "Normal"
  auto_renew_period     = 1
}

# 输出公网 IP
output "instance_public_ip" {
  value = alicloud_instance.default. public_ip
}