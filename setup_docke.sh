#!/bin/bash
# 脚本说明：在阿里云 ECS (Ubuntu/Alibaba Cloud Linux) 上自动安装 Docker 和 Docker Compose

# 1. 更新系统软件包
apt-get update -y || yum update -y

# 2. 安装必要的依赖 (根据操作系统尝试安装)
apt-get install -y ca-certificates curl gnupg lsb-release || yum install -y yum-utils

# 3. 安装 Docker (使用官方安装脚本，最通用的方法)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 4. 启动 Docker 并设置开机自启
systemctl start docker
systemctl enable docker

# 5. 安装 Docker Compose
# 获取最新版本号 (或者您可以硬编码版本，如 v2.29.0)
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

# 下载 Docker Compose 二进制文件
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 赋予执行权限
chmod +x /usr/local/bin/docker-compose

# 6. 验证安装 (将结果输出到日志文件，方便排查)
echo "------------------------------------------------" >> /root/install_log.txt
echo "Docker Version:" >> /root/install_log.txt
docker --version >> /root/install_log.txt
echo "Docker Compose Version:" >> /root/install_log.txt
docker-compose --version >> /root/install_log.txt
echo "------------------------------------------------" >> /root/install_log.txt