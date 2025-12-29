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


# ========== 实例信息 ==========

output "instance_id" {
  description = "实例 ID"
  value       = alicloud_instance.spot_instance.id
}

output "instance_name" {
  description = "实例名称"
  value       = alicloud_instance.spot_instance.instance_name
}

output "instance_type" {
  description = "实例规格"
  value       = alicloud_instance.spot_instance. instance_type
}

output "availability_zone" {
  description = "可用区"
  value       = alicloud_instance.spot_instance.availability_zone
}

# ========== IP 地址 ==========

output "public_ip" {
  description = "公网 IP（根据配置自动选择 EIP 或实例公网 IP）"
  value       = var.use_eip ? (
    length(alicloud_eip_address.eip) > 0 ? alicloud_eip_address.eip[0].ip_address : "EIP 创建中..."
  ) : (
    alicloud_instance.spot_instance. public_ip != "" ? alicloud_instance.spot_instance.public_ip : "无公网 IP"
  )
}

output "private_ip" {
  description = "私网 IP"
  value       = alicloud_instance.spot_instance.private_ip
}

output "eip_address" {
  description = "弹性公网 IP（如果启用）"
  value       = var.use_eip ? alicloud_eip_address.eip[0].ip_address : "未使用 EIP"
}



output "security_group_id" {
  description = "安全组 ID"
  value       = alicloud_security_group.sg.id
}

# ========== Spot 实例信息 ==========

output "spot_strategy" {
  description = "抢占策略"
  value       = var.spot_strategy
}

output "spot_price_limit" {
  description = "价格上限"
  value       = var.spot_strategy == "SpotWithPriceLimit" ? "${var.spot_price_limit} 元/小时" : "跟随市场价"
}

output "spot_duration" {
  description = "保护期"
  value       = var.spot_duration == 0 ? "无保护期" : "${var.spot_duration} 小时"
}

# ========== 连接信息 ==========

output "ssh_command" {
  description = "SSH 连接命令"
  value       = var.use_eip ? (
    length(alicloud_eip_address.eip) > 0 ? "ssh ${var.username}@${alicloud_eip_address.eip[0].ip_address}" : "等待 EIP 分配..."
  ) : (
    alicloud_instance.spot_instance.public_ip != "" ?  "ssh ${var.username}@${alicloud_instance.spot_instance.public_ip}" : "无法连接：没有公网 IP"
  )
}

output "web_url" {
  description = "Web 访问地址"
  value       = var.use_eip ? (
    length(alicloud_eip_address.eip) > 0 ? "http://${alicloud_eip_address.eip[0].ip_address}" : "等待 EIP 分配..."
  ) : (
    alicloud_instance.spot_instance. public_ip != "" ? "http://${alicloud_instance.spot_instance.public_ip}" :  "无公网访问"
  )
}

# ========== 网络配置摘要 ==========

output "network_summary" {
  description = "网络配置摘要"
  value = {
    use_eip            = var.use_eip
    public_ip_type     = var.use_eip ? "EIP (弹性公网 IP)" : "NAT (临时公网 IP)"
    eip_bandwidth      = var.use_eip ? var.eip_bandwidth : 0
    internet_charge    = var.use_eip ? "EIP 按流量计费" : "实例按流量计费"
  }
}

# ========== 完整连接信息 ==========

output "connection_info" {
  description = "完整的连接信息"
  value = {
    public_ip    = var.use_eip ? (
      length(alicloud_eip_address.eip) > 0 ? alicloud_eip_address.eip[0].ip_address :  "pending"
    ) : alicloud_instance.spot_instance. public_ip
    private_ip   = alicloud_instance.spot_instance.private_ip
    ssh_command  = var.use_eip ? (
      length(alicloud_eip_address. eip) > 0 ? "ssh ${var.username}@${alicloud_eip_address.eip[0].ip_address}" : "pending"
    ) : "ssh ${var.username}@${alicloud_instance.spot_instance. public_ip}"
    ssh_user     = var.username
    instance_id  = alicloud_instance.spot_instance.id
  }
}

# ========== 成本估算 ==========

output "cost_estimate" {
  description = "成本估算（仅供参考）"
  value = {
    note            = "抢占式实例价格浮动，以下为估算"
    instance_type   = var.instance_type
    spot_strategy   = var.spot_strategy
    estimated_savings = "相比按量付费节省 70-90%"
    bandwidth_cost  = var.use_eip 
      "EIP 带宽:  ${var.eip_bandwidth}Mbps 按流量计费" : 
      "实例带宽:  ${var.internet_max_bandwidth_out}Mbps 按流量计费"
  }
}

# ========== 快速参考 ==========

output "quick_reference" {
  description = "快速参考信息"
  value = <<-EOT
  
  ╔════════════════════════════════════════════════════════════╗
  ║          阿里云抢占式实例 - 连接信息                        ║
  ╠════════════════════════════════════════════════════════════╣
  ║ 实例 ID:     ${alicloud_instance.spot_instance.id}
  ║ 实例类型:    ${var.instance_type}
  ║ 可用区:      ${alicloud_instance.spot_instance. availability_zone}
  ║ 
  ║ 公网 IP:     ${var.use_eip ? (length(alicloud_eip_address.eip) > 0 ? alicloud_eip_address.eip[0].ip_address : "等待分配... ") : (alicloud_instance.spot_instance.public_ip != "" ? alicloud_instance.spot_instance. public_ip : "无")}
  ║ 私网 IP:    ${alicloud_instance.spot_instance.private_ip}
  ║ 
  ║ SSH 连接: 
  ║   ${var.use_eip ? (length(alicloud_eip_address.eip) > 0 ? "ssh ${var.username}@${alicloud_eip_address.eip[0]. ip_address}" : "等待 EIP... ") : (alicloud_instance. spot_instance.public_ip != "" ? "ssh ${var.username}@${alicloud_instance. spot_instance.public_ip}" : "配置公网访问")}
  ║ 
  ║ Web 访问:
  ║   ${var.use_eip ? (length(alicloud_eip_address.eip) > 0 ? "http://${alicloud_eip_address. eip[0].ip_address}" : "等待 EIP...") : (alicloud_instance.spot_instance.public_ip != "" ? "http://${alicloud_instance.spot_instance. public_ip}" : "配置公网访问")}
  ║ 
  ║ 抢占策略:    ${var.spot_strategy}
  ║ 保护期:      ${var.spot_duration == 0 ? "无保护期（最低价）" : "${var.spot_duration} 小时"}
  ╚════════════════════════════════════════════════════════════╝
  
  💡 提示: 
  - 查看安装日志:  ssh ${var.username}@<IP> "sudo tail -f /var/log/setup-docker.log"
  - 运行示例应用: ssh ${var.username}@<IP> "cd ~/docker && docker-compose -f docker-compose.example.yml up -d"
  - 启动监控: ssh ${var.username}@<IP> "~/spot-monitor.sh &"
  
  EOT
}