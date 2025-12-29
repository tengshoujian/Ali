output "instance_id" {
  description = "ECS 实例 ID"
  value       = alicloud_instance.spot_instance.id
}

output "public_ip" {
  description = "实例公网 IP"
  value       = alicloud_instance.spot_instance.public_ip
}

output "private_ip" {
  description = "实例私网 IP"
  value       = alicloud_instance.spot_instance.private_ip
}

output "ssh_command" {
  description = "SSH 连接命令（新用户）"
  value       = "ssh ${var.username}@${alicloud_instance.spot_instance.public_ip}"
}

output "docker_info" {
  description = "Docker 安装信息"
  value = {
    compose_version = var.docker_compose_version
    data_root      = var.docker_data_root
  }
}