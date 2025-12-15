provider "alicloud" {
    region = "cn-hangzhou" # Replace with your desired region
}

resource "alicloud_vpc" "main" {
    name       = "my-vpc"
    cidr_block = "192.168.0.0/16"
}

resource "alicloud_vswitch" "main" {
    vpc_id            = alicloud_vpc.main.id
    cidr_block        = "192.168.1.0/24"
    availability_zone = "cn-hangzhou-b" # Replace with your desired zone
    name              = "my-vswitch"
}

resource "alicloud_security_group" "main" {
    name        = "my-security-group"
    description = "Security group for ECS instance"
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
    instance_name       = "my-ecs-instance"
    availability_zone   = alicloud_vswitch.main.availability_zone
    instance_type       = "ecs.t5-lc2m1.nano" # Replace with your desired instance type
    security_group_id   = alicloud_security_group.main.id
    vswitch_id          = alicloud_vswitch.main.id
    image_id            = "ubuntu_20_04_x64_20G_alibase_20230618.vhd" # Replace with your desired image
    internet_max_bandwidth_out = 10
    allocate_public_ip  = true
    password            = "YourPassword123!" # Replace with a secure password
}

output "instance_public_ip" {
    value = alicloud_instance.main.public_ip
}