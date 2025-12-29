#!/bin/bash

###############################################################################
# Docker & Docker Compose 安装脚本
# 使用 Terraform templatefile 生成
# 用户:  ${username}
###############################################################################

set -euo pipefail  # 遇到错误立即退出

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
echo "开始执行 Docker 安装脚本"
echo "时间:  $(date)"
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

# 禁用交换分区（Docker 推荐）
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

echo "✓ 系统基础配置完成"

###############################################################################
# 2. 更新系统
###############################################################################

echo "[2/8] 更新系统软件包..."

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# 安装必要的工具
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
    tree

echo "✓ 系统更新完成"

###############################################################################
# 3. 创建用户
###############################################################################

echo "[3/8] 创建用户 $USERNAME..."

# 创建用户
if id "$USERNAME" &>/dev/null; then
    echo "用户 $USERNAME 已存在"
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "✓ 用户 $USERNAME 创建成功"
fi

# 添加到 sudo 组
usermod -aG sudo "$USERNAME"

# 配置无密码 sudo
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers. d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# 配置 SSH
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh

echo "$PUBLIC_KEY" > /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

echo "✓ 用户配置完成"

###############################################################################
# 4. 安装 Docker
###############################################################################

echo "[4/8] 安装 Docker..."

# 删除旧版本
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 添加 Docker 官方 GPG 密钥
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker. gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 添加 Docker 仓库
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新并安装 Docker
apt-get update

if [ "$DOCKER_VERSION" = "latest" ]; then
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    # 安装特定版本
    VERSION_STRING=$(apt-cache madison docker-ce | grep "$DOCKER_VERSION" | head -1 | awk '{print $3}')
    apt-get install -y docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd. io docker-buildx-plugin docker-compose-plugin
fi

# 启动 Docker
systemctl enable docker
systemctl start docker

# 验证安装
docker --version

echo "✓ Docker 安装完成"

###############################################################################
# 5. 安装 Docker Compose (独立版本)
###############################################################################

echo "[5/8] 安装 Docker Compose..."

# 下载 Docker Compose
COMPOSE_URL="https://github.com/docker/compose/releases/download/v$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)"
curl -L "$COMPOSE_URL" -o /usr/local/bin/docker-compose

# 添加执行权限
chmod +x /usr/local/bin/docker-compose

# 创建符号链接
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# 验证安装
docker-compose --version

echo "✓ Docker Compose 安装完成"

###############################################################################
# 6. 配置 Docker
###############################################################################

echo "[6/8] 配置 Docker..."

# 将用户添加到 docker 组
usermod -aG docker $USERNAME

# 配置 Docker daemon
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
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
      "Soft": 64000
    }
  }
}
EOF

# 重启 Docker
systemctl daemon-reload
systemctl restart docker

echo "✓ Docker 配置完成"

###############################################################################
# 7. 创建工作目录和示例项目
###############################################################################

echo "[7/8] 创建工作目录..."

# 创建项目目录
mkdir -p /home/$USERNAME/projects
mkdir -p /home/$USERNAME/docker

# 创建示例 docker-compose.yml
cat > /home/$USERNAME/docker/docker-compose.example.yml <<'COMPOSE'
version: '3.8'

services:
  nginx:
    image: nginx:latest
    container_name: nginx-example
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html: ro
    restart: unless-stopped
    
  # 示例：添加更多服务
  # redis:
  #   image: redis:alpine
  #   container_name:  redis
  #   ports:
  #     - "6379:6379"
  #   restart: unless-stopped
COMPOSE

# 创建示例 HTML
mkdir -p /home/$USERNAME/docker/html
cat > /home/$USERNAME/docker/html/index. html <<HTML
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Docker</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #0db7ed; }
    </style>
</head>
<body>
    <h1>🐳 Docker is running!</h1>
    <p>Hostname: $HOSTNAME</p>
    <p>User: $USERNAME</p>
    <p>Docker version: $(docker --version)</p>
</body>
</html>
HTML

# 创建 README
cat > /home/$USERNAME/README.md <<'README'
# Docker Server Setup

## Docker Commands

### 基本命令
\`\`\`bash
# 查看 Docker 版本
docker --version
docker-compose --version

# 查看运行中的容器
docker ps

# 查看所有容器
docker ps -a

# 查看镜像
docker images

# 查看 Docker 信息
docker info
\`\`\`

### 运行示例项目
\`\`\`bash
cd ~/docker
docker-compose -f docker-compose.example.yml up -d
\`\`\`

### 常用操作
\`\`\`bash
# 停止所有容器
docker stop $(docker ps -q)

# 删除所有停止的容器
docker container prune -f

# 删除未使用的镜像
docker image prune -a -f

# 查看容器日志
docker logs <container_name>

# 进入容器
docker exec -it <container_name> bash
\`\`\`

## Useful Aliases
已添加到 ~/.bashrc:
- `dps` - docker ps
- `dimg` - docker images
- `dlog` - docker logs
- `dexec` - docker exec -it
README

# 设置目录权限
chown -R $USERNAME:$USERNAME /home/$USERNAME

echo "✓ 工作目录创建完成"

###############################################################################
# 8. 配置用户环境
###############################################################################

echo "[8/8] 配置用户环境..."

# 配置 .bashrc
cat >> /home/$USERNAME/.bashrc <<'BASHRC'

# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dlog='docker logs'
alias dexec='docker exec -it'
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias dclogs='docker-compose logs -f'

# 自定义提示符
export PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '

# Docker completion
if [ -f /usr/share/bash-completion/completions/docker ]; then
    .  /usr/share/bash-completion/completions/docker
fi

echo "🐳 Docker is ready!  Type 'docker --version' to verify."
BASHRC

chown $USERNAME:$USERNAME /home/$USERNAME/.bashrc

# 配置 SSH
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication no/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

systemctl restart sshd

echo "✓ 用户环境配置完成"

###############################################################################
# 完成
###############################################################################

echo "=================================================="
echo "✅ Docker 安装脚本执行完成！"
echo "=================================================="
echo ""
echo "系统信息:"
echo "  - 主机名: $HOSTNAME"
echo "  - 用户: $USERNAME"
echo "  - 时区: $TIMEZONE"
echo ""
echo "已安装:"
echo "  - Docker:  $(docker --version)"
echo "  - Docker Compose: $(docker-compose --version)"
echo ""
echo "SSH 连接:"
echo "  ssh $USERNAME@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "工作目录:"
echo "  - /home/$USERNAME/projects"
echo "  - /home/$USERNAME/docker"
echo ""
echo "示例项目:"
echo "  cd ~/docker"
echo "  docker-compose -f docker-compose.example.yml up -d"
echo ""
echo "日志文件:  $LOG_FILE"
echo "=================================================="

# 记录完成时间
echo "安装完成时间: $(date)" >> $LOG_FILE