
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
# resource "alicloud_instance" "server" {
#   instance_name        = var.instance_name
#   instance_type        = var.instance_type
#   image_id             = var.image_id
#   system_disk_category = "cloud_essd"
#   system_disk_size     = 40
#   vswitch_id           = alicloud_vswitch.vsw.id
#   security_groups      = alicloud_security_group.default.*.id
#   password             = var.password
#   # key_name = alicloud_ecs_key_pair.my_keypair.key_pair_name
#   internet_max_bandwidth_out = var.internet_bandwidth
#   internet_charge_type       = "PayByTraffic"

  
#   # 初始化脚本 - 安装基础依赖
#   # user_data = file("setup_docker.sh")
#   user_data = templatefile("${path.module}/scripts/setup-docker.sh", {
#     username       = var.username
#     public_key     = var.public_key
#     docker_version = var.docker_version
#     compose_version = var.compose_version
#     timezone       = var.timezone
#     hostname       = var.instance_name
#   })
  
#   tags = {
#     Name        = var.instance_name
#     Environment = var.environment
#     ManagedBy   = "Terraform"
#   }
# }

# resource "alicloud_ecs_key_pair" "my_keypair" {
#   key_pair_name = "my-terraform-key"
#   public_key    = file(var.public_key)  # 读取公钥内容
# }

resource "alicloud_instance" "spot_instance" {
  # 实例基本配置
  instance_name   = var.instance_name
  host_name       = var.instance_name
  instance_type   = var.instance_type
  image_id        = var.image_id
  
  # 网络配置
  security_groups            = alicloud_security_group.default.*.id
  vswitch_id                 = alicloud_vswitch.vsw.id
  internet_max_bandwidth_out = var.use_eip ? 0 :  var.internet_bandwidth
  internet_charge_type       = var.use_eip ? null : "PayByTraffic"
  # internet_max_bandwidth_out = var.internet_bandwidth
  # internet_charge_type       = "PayByTraffic"
  password = var.password
  # 密钥对
  # key_name = alicloud_ecs_key_pair.key_pair.key_pair_name
  
  # 系统盘配置
  system_disk_category = "cloud_essd"
  system_disk_size     = 40
  
  # ========== 抢占式实例配置（关键部分） ==========
  
  # 实例计费类型：PostPaid（按量付费）
  instance_charge_type = "PostPaid"
  
  # 抢占策略
  spot_strategy = var.spot_strategy  # "SpotWithPriceLimit" 或 "SpotAsPriceGo"
  
  # 抢占式实例的价格上限（仅当 spot_strategy = "SpotWithPriceLimit" 时需要）
  spot_price_limit = var.spot_price_limit
  
  # 抢占式实例中断模式
  spot_duration = var.spot_duration  # 0 表示无保护期（默认），1-6 表示保护期小时数
  
  # ==============================================
 
  
  # User data（启动脚本）
  user_data = base64encode(templatefile("${path.module}/scripts/setup-docker.sh", {
    username        = var.username
    public_key      = local.ssh_public_key
    docker_version  = var.docker_version
    compose_version = var.compose_version
    timezone        = var.timezone
    hostname        = var.hostname
  }))
  
  tags = {
    Name         = var.hostname
    Environment  = var.environment
    InstanceType = "spot"
    ManagedBy    = "Terraform"
    User         = var.username
  }
  
  # 生命周期
  lifecycle {
    ignore_changes = [
      instance_charge_type,
      spot_price_limit,
    ]
  }
}

 locals {
  # 读取 SSH 公钥（从内容或文件）
  ssh_public_key = var.public_key != "" ? var.public_key :  trimspace(file(var.public_key_path))
  # 是否随 VPC 释放
  force_delete = true
  }
# 弹性公网 IP（可选）
resource "alicloud_eip_address" "eip" {
  count                = var.use_eip ? 1 : 0
  address_name         = "${var.hostname}-eip"
  bandwidth            = var.eip_bandwidth
  internet_charge_type = "PayByTraffic"
  payment_type         = "PayAsYouGo"
  
  tags = {
    Name = "${var.hostname}-eip"
  }
}

# 绑定 EIP
resource "alicloud_eip_association" "eip_asso" {
  count         = var.use_eip ?  1 : 0
  allocation_id = alicloud_eip_address.eip[0]. id
  instance_id   = alicloud_instance.spot_instance.id
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

