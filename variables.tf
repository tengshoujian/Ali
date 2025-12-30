
variable "region" {
  default = "ap-southeast-1"
}

# 实例配置变量
variable "instance_name" {
  description = "ECS 实例名称"
  type        = string
  default     = "docker-server"
}

variable "instance_type" {
  description = "ECS 实例规格"
  type        = string
  default     = "ecs.t6-c1m2.large"
}

variable "image_id" {
  description = "操作系统镜像 ID"
  type        = string
  # Ubuntu 22.04
  default     = "ubuntu_22_04_x64_20G_alibase_20231221.vhd"
}

variable "password" {
  default = "Test@12345"
}

variable "ecs_count" {
  default = 1
}

variable "internet_bandwidth" {
  default = "10"
}

variable "public_key" {
  description = "ssh public key"
  type = string 
  default     = "" 
}

variable "public_key_path" {
  description = "SSH 公钥文件路径（如果 public_key 变量为空，则从该路径读取公钥内容）"
  type        = string
  default     = "./id_rsa.pub" 
}
variable "private_key_path" {
  description = "SSH 私钥文件路径"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "environment" {
  description = "环境标识"
  type        = string
  default     = "production"
}

# 用户配置变量
variable "username" {
  description = "要创建的新用户名"
  type        = string
  default     = "prod-user"
}

variable "timezone" {
  description = "系统时区"
  type        = string
  default     = "Asia/Shanghai"
}

variable "hostname" {
  description = "主机名"
  type        = string
  default     = "prod-docker-server"
}

variable "docker_version" {
  description = "Docker 版本"
  type        = string
  default     = "latest"  # 或指定版本如 "24.0"
}

variable "compose_version" {
  description = "Docker Compose 版本"
  type        = string
  default     = "2.24.0"  # 使用最新稳定版
}
variable "user_password" {
  description = "新用户的密码（留空则不设置密码）"
  type        = string
  default     = "Test@12345"
  sensitive   = true
}

# Docker 配置变量
variable "docker_compose_version" {
  description = "Docker Compose 版本"
  type        = string
  default     = "2.24.5"
}

variable "docker_data_root" {
  description = "Docker 数据目录"
  type        = string
  default     = "/var/lib/docker"
}

variable "docker_registry_mirrors" {
  description = "Docker 镜像加速器列表"
  type        = list(string)
  default     = [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}

variable "spot_strategy" {
  description = "抢占式实例策略"
  type        = string
  default     = "SpotAsPriceGo"
  # SpotWithPriceLimit:  设置价格上限
  # SpotAsPriceGo: 系统自动出价，最高按量付费价格
  
  validation {
    condition     = contains(["SpotWithPriceLimit", "SpotAsPriceGo"], var.spot_strategy)
    error_message = "spot_strategy 必须是 'SpotWithPriceLimit' 或 'SpotAsPriceGo'"
  }
}

variable "spot_price_limit" {
  description = "抢占式实例价格上限（每小时）"
  type        = number
  default     = 0.5
  # 仅当 spot_strategy = "SpotWithPriceLimit" 时生效
  # 建议设置为按量付费价格的 10%-30%
}

variable "spot_duration" {
  description = "抢占式实例保护期（小时）"
  type        = number
  default     = 0
  # 0:  无保护期（推荐，价格最低）
  # 1-6: 保护期 1-6 小时（保护期内不会被回收）
  
  validation {
    condition     = var.spot_duration >= 0 && var.spot_duration <= 6
    error_message = "spot_duration 必须在 0-6 之间"
  }
}
variable "use_eip" {
  description = "是否使用弹性公网 IP"
  type        = bool
  default     = true
}

variable "eip_bandwidth" {
  description = "EIP 带宽 (Mbps)"
  type        = number
  default     = 10
}
