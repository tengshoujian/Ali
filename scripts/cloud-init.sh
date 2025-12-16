#!/bin/bash
# Cloud-Init 脚本 - 基础系统初始化

set -e

# 设置主机名
hostnamectl set-hostname ${hostname}

# 更新系统
apt-get update -y || yum update -y

# 安装基础工具
if command -v apt-get &> /dev/null; then
    apt-get install -y curl wget git vim htop net-tools
elif command -v yum &> /dev/null; then
    yum install -y curl wget git vim htop net-tools
fi

# 配置时区
timedatectl set-timezone Asia/Shanghai

# 禁用 swap（Docker 最佳实践）
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

echo "Cloud-Init 完成"