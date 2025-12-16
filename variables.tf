
variable "region" {
  default = "cn-chengdu"
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


variable "key_pair_name" {
  description = "SSH 密钥对名称"
  type        = string
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
variable "new_user" {
  description = "要创建的新用户名"
  type        = string
  default     = "deployuser"
}

variable "user_password" {
  description = "新用户的密码（留空则不设置密码）"
  type        = string
  default     = "123456"
  sensitive   = true
}


variable "ssh_public_key" {
  description = "要添加到新用户的 SSH 公钥"
  type        = string
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