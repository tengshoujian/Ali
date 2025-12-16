
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
  user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.sh", {
    hostname = var.instance_name
  }))
  
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
  name   = var.instance_name
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

# 等待实例完全启动
resource "time_sleep" "wait_for_instance" {
  depends_on = [alicloud_instance.server]
  
  create_duration = "30s"
}

# 上传 setup.sh 脚本到服务器
resource "null_resource" "upload_setup_script" {
  depends_on = [time_sleep.wait_for_instance]
  
  # 当脚本文件变化时重新上传
  triggers = {
    script_hash = filemd5("${path.module}/scripts/setup.sh")
  }
  
  connection {
    type        = "ssh"
    host        = alicloud_instance.server.public_ip
    user        = "root"
    password =  var.password
    timeout     = "5m"
  }
  
  # 上传脚本文件
  provisioner "file" {
    source      = "${path.module}/scripts/setup. sh"
    destination = "/tmp/setup.sh"
  }
  
  # 上传 daemon.json 配置文件
  provisioner "file" {
    content = templatefile("${path.module}/configs/daemon.json", {
      data_root       = var.docker_data_root
      registry_mirrors = jsonencode(var.docker_registry_mirrors)
    })
    destination = "/tmp/daemon.json"
  }
}

# 执行 setup. sh 脚本
resource "null_resource" "run_setup_script" {
  depends_on = [null_resource.upload_setup_script]
  
  # 当变量变化时重新执行
  triggers = {
    script_hash    = filemd5("${path. module}/scripts/setup.sh")
    new_user       = var.new_user
    docker_compose_version = var.docker_compose_version
  }
  
  connection {
    type        = "ssh"
    host        = alicloud_instance.server.public_ip
    user        = "root"
    private_key = file(var.private_key_path)
    timeout     = "10m"
  }
  
  # 执行脚本
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup. sh",
      
      # 导出环境变量传递给脚本
      "export NEW_USER='${var.new_user}'",
      "export USER_PASSWORD='${var.user_password}'",
      "export DOCKER_COMPOSE_VERSION='${var.docker_compose_version}'",
      
      # 执行脚本
      "bash /tmp/setup.sh",
      
      # 配置 Docker daemon
      "mkdir -p /etc/docker",
      "mv /tmp/daemon.json /etc/docker/daemon.json",
      "systemctl daemon-reload",
      "systemctl restart docker",
      
      # 清理临时文件
      "rm -f /tmp/setup.sh",
      
      # 验证安装
      "docker --version",
      "docker-compose --version",
      "systemctl status docker --no-pager",
    ]
  }
}

# 配置防火墙规则（可选）
resource "null_resource" "configure_firewall" {
  depends_on = [null_resource. run_setup_script]
  
  connection {
    type        = "ssh"
    host        = alicloud_instance.server.public_ip
    user        = "root"
    private_key = file(var.private_key_path)
  }
  
  provisioner "remote-exec" {
    inline = [
      # 如果使用 UFW (Ubuntu/Debian)
      "command -v ufw >/dev/null && ufw allow 22/tcp || true",
      "command -v ufw >/dev/null && ufw allow 80/tcp || true",
      "command -v ufw >/dev/null && ufw allow 443/tcp || true",
      
      # 如果使用 firewalld (CentOS/RHEL)
      "command -v firewall-cmd >/dev/null && firewall-cmd --permanent --add-service=ssh || true",
      "command -v firewall-cmd >/dev/null && firewall-cmd --permanent --add-service=http || true",
      "command -v firewall-cmd >/dev/null && firewall-cmd --permanent --add-service=https || true",
      "command -v firewall-cmd >/dev/null && firewall-cmd --reload || true",
    ]
  }
}

# 创建时间资源用于等待
resource "time_sleep" "wait_for_setup" {
  depends_on = [null_resource.configure_firewall]
  
  create_duration = "10s"
}