#!/bin/bash

###############################################################################
# 阿里云抢占式实例 - Docker 安装脚本
# 使用 Terraform templatefile 生成
###############################################################################

set -euo pipefail

# 变量
USERNAME="${username}"
PUBLIC_KEY="${public_key}"
DOCKER_VERSION="${docker_version}"
COMPOSE_VERSION="${compose_version}"
TIMEZONE="${timezone}"
HOSTNAME="${hostname}"

# 日志文件
LOG_FILE="/var/log/setup-docker.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "阿里云抢占式实例初始化"
echo "时间: $(date)"
echo "主机名: $HOSTNAME"
echo "用户: $USERNAME"
echo "=================================================="

###############################################################################
# 1. 系统配置
###############################################################################

echo "[1/8] 配置系统基础设置..."

# 设置主机名
hostnamectl set-hostname "$HOSTNAME"
echo "127.0.0.1 $HOSTNAME" >> /etc/hosts

# 设置时区
timedatectl set-timezone "$TIMEZONE"

# 禁用交换分区
swapoff -a || true
sed -i '/ swap / s/^/#/' /etc/fstab || true

echo "✓ 系统基础配置完成"

###############################################################################
# 2. 配置阿里云镜像源
###############################################################################

echo "[2/8] 配置阿里云软件源..."

# 备份原有源
cp /etc/apt/sources.list /etc/apt/sources.list.backup

# 使用阿里云镜像源
cat > /etc/apt/sources.list <<'EOF'
deb https://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF

# 更新系统
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# 安装必要工具
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    git \
    vim \
    htop \
    net-tools \
    unzip \
    jq \
    tree \
    iotop

echo "✓ 软件源配置完成"

###############################################################################
# 3. 创建用户
###############################################################################

echo "[3/8] 创建用户 $USERNAME..."

# 创建用户
if id "$USERNAME" &>/dev/null; then
    echo "⚠ 用户 $USERNAME 已存在"
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "✓ 用户 $USERNAME 创建成功"
fi

# 添加到 sudo 组
usermod -aG sudo "$USERNAME"
echo "✓ 用户已添加到 sudo 组"

# 配置无密码 sudo - 修复：确保目录存在
echo "配置 sudo 权限..."

# 确保 sudoers. d 目录存在
SUDOERS_DIR="/etc/sudoers.d"
if [ ! -d "$SUDOERS_DIR" ]; then
    echo "创建 $SUDOERS_DIR 目录..."
    mkdir -p "$SUDOERS_DIR"
    chmod 755 "$SUDOERS_DIR"
fi

# 创建 sudoers 文件
SUDOERS_FILE="$SUDOERS_DIR/$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

# 验证 sudoers 文件语法
if visudo -c -f "$SUDOERS_FILE" &>/dev/null; then
    echo "✓ Sudoers 文件语法验证通过:  $SUDOERS_FILE"
else
    echo "⚠ Sudoers 文件语法错误，回退到直接修改 /etc/sudoers"
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

# 配置 SSH
echo "配置 SSH..."
SSH_DIR="/home/$USERNAME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# 确保 SSH 目录存在
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
echo "✓ SSH 目录创建:  $SSH_DIR"

# 写入公钥
echo "$PUBLIC_KEY" > "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
echo "✓ SSH 密钥配置完成"

# 验证文件
if [ -f "$SUDOERS_FILE" ]; then
    echo "✓ Sudoers 文件存在: $(ls -la $SUDOERS_FILE)"
fi

if [ -f "$AUTHORIZED_KEYS" ]; then
    echo "✓ SSH 密钥文件存在: $(ls -la $AUTHORIZED_KEYS)"
fi

echo "✓ 用户配置完成"

###############################################################################
# 4. 安装 Docker（使用阿里云镜像）
###############################################################################

echo "[4/8] 安装 Docker..."

# 删除旧版本
apt-get remove -y docker docker-engine docker. io containerd runc 2>/dev/null || true

# 添加 Docker GPG 密钥（使用阿里云镜像）
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 添加 Docker 仓库（使用阿里云镜像）
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新并安装
apt-get update

if [ "$DOCKER_VERSION" = "latest" ]; then
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    VERSION_STRING=$(apt-cache madison docker-ce | grep "$DOCKER_VERSION" | head -1 | awk '{print $3}')
    if [ -n "$VERSION_STRING" ]; then
        apt-get install -y docker-ce="$VERSION_STRING" docker-ce-cli="$VERSION_STRING" containerd.io docker-buildx-plugin docker-compose-plugin
    else
        echo "⚠ 未找到 Docker 版本 $DOCKER_VERSION，安装最新版"
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
fi

# 启动 Docker
systemctl enable docker
systemctl start docker

echo "✓ Docker 安装完成:  $(docker --version)"

###############################################################################
# 5. 配置 Docker 阿里云镜像加速
###############################################################################

echo "[5/8] 配置 Docker 镜像加速..."

mkdir -p /etc/docker

# 配置阿里云镜像加速和其他优化
cat > /etc/docker/daemon.json <<'DOCKERCONFIG'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": false,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft":  64000
    }
  }
}
DOCKERCONFIG

# 重启 Docker
systemctl daemon-reload
systemctl restart docker

sleep 3

echo "✓ Docker 镜像加速配置完成"

###############################################################################
# 6. 安装 Docker Compose
###############################################################################

echo "[6/8] 安装 Docker Compose..."

# 方式 1: 使用 APT 安装插件版本（最可靠）
echo "通过 APT 安装 Docker Compose 插件..."
apt-get install -y docker-compose-plugin

# 验证插件安装
if docker compose version &>/dev/null; then
    echo "✓ Docker Compose 插件安装成功"
    COMPOSE_PLUGIN_VERSION=$(docker compose version --short)
    echo "  版本: $COMPOSE_PLUGIN_VERSION"
    
    # 创建兼容性符号链接
    cat > /usr/local/bin/docker-compose <<'WRAPPER'
#!/bin/bash
exec docker compose "$@"
WRAPPER
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    echo "✓ 已创建 docker-compose 兼容命令"
else
    echo "⚠️ 插件安装失败，尝试安装独立版本..."
    
    # 方式 2: 从 APT 安装独立版本
    apt-get install -y docker-compose
    
    if docker-compose version &>/dev/null; then
        echo "✓ Docker Compose 独立版安装成功"
        docker-compose version
    else
        echo "❌ Docker Compose 安装失败"
    fi
fi

echo "✓ Docker Compose 安装完成"

###############################################################################
# 7. 配置用户和 Docker 组
###############################################################################

echo "[7/8] 配置用户权限..."

# 将用户添加到 docker 组
usermod -aG docker "$USERNAME"

# 验证 Docker
if systemctl is-active --quiet docker; then
    echo "✓ Docker 服务运行正常"
else
    echo "⚠ Docker 服务未正常启动"
    systemctl status docker
fi

echo "✓ 用户权限配置完成"

