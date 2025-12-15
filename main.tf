provider "alicloud" {
  region = "cn-hangzhou"
}

resource "alicloud_vpc" "main" {
  vpc_name   = "my-vpc"
  cidr_block = "192.168.0.0/16"
}

resource "alicloud_vswitch" "main" {
  vpc_id       = alicloud_vpc.main.id
  cidr_block   = "192.168.1.0/24"
  zone_id      = "cn-hangzhou-b"
  vswitch_name = "my-vswitch"
}

resource "alicloud_security_group" "main" {
  security_group_name = "my-security-group"
  vpc_id              = alicloud_vpc.main.id
  description         = "Security group for ECS instance"
}

resource "alicloud_security_group_rule" "allow_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_instance" "main" {
  instance_name              = "my-ecs-instance"
  instance_type              = "ecs.t5-lc2m1.nano"
  vswitch_id                 = alicloud_vswitch.main.id
  security_groups            = [alicloud_security_group.main.id]  # 用 security_groups 而非 security_group_ids
  image_id                   = "ubuntu_20_04_x64_20G_alibase_20230618.vhd"
  internet_max_bandwidth_out = 10
  password                   = "YourPassword123!"
}

output "instance_public_ip" {
  value = alicloud_instance.main. public_ip
}