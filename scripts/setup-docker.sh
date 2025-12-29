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

###############################################################################
# 8. 创建工作目录和示例
###############################################################################

echo "[8/8] 创建工作目录..."

# 创建目录
mkdir -p /home/$USERNAME/projects
mkdir -p /home/$USERNAME/docker
mkdir -p /home/$USERNAME/docker/html  # ✅ 确保目录存在

# 创建示例 compose 文件
cat > /home/$USERNAME/docker/docker-compose.example.yml <<'COMPOSE'
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: nginx-example
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
    restart: unless-stopped
    
  whoami:
    image: traefik/whoami
    container_name: whoami-example
    ports:
      - "8080:80"
    restart: unless-stopped
COMPOSE

# ✅ 修复：先获取实例信息，然后创建 HTML
INSTANCE_ID=$(curl -s http://100.100.100.200/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
PUBLIC_IP=$(curl -s http://100.100.100.200/latest/meta-data/eipv4 2>/dev/null || curl -s http://100.100.100.200/latest/meta-data/public-ipv4 2>/dev/null || echo "N/A")
CURRENT_TIME=$(date)

# 创建示例网页（使用变量替换，不使用命令替换）
cat > /home/$USERNAME/docker/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>阿里云抢占式实例</title>
    <meta charset="utf-8">
    <style>
        body {
            font-family: 'PingFang SC', 'Microsoft YaHei', Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background:  linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        h1 { 
            font-size: 3em; 
            margin-bottom: 20px; 
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .info {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 15px;
            display: inline-block;
            margin-top: 30px;
            text-align: left;
            backdrop-filter: blur(10px);
        }
        .info p { 
            margin: 10px 0; 
            font-size: 1.2em; 
        }
        .status { 
            display: inline-block;
            padding: 5px 15px;
            background: #4CAF50;
            border-radius: 20px;
            margin-left: 10px;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        . link {
            margin-top: 30px;
        }
        .link a {
            color: white;
            text-decoration: none;
            padding: 10px 20px;
            background: rgba(255,255,255,0.2);
            border-radius: 5px;
            display: inline-block;
            margin: 10px;
            transition: all 0.3s;
        }
        .link a:hover {
            background: rgba(255,255,255,0.3);
            transform: translateY(-2px);
        }
    </style>
</head>
<body>
    <h1>🐳 阿里云抢占式实例运行中！</h1>
    <div class="info">
        <p><strong>主机名:</strong> $HOSTNAME</p>
        <p><strong>用户: </strong> $USERNAME</p>
        <p><strong>实例 ID:</strong> $INSTANCE_ID</p>
        <p><strong>公网 IP:</strong> $PUBLIC_IP</p>
        <p><strong>部署时间:</strong> $CURRENT_TIME</p>
        <p><strong>状态:</strong> <span class="status">运行中</span></p>
    </div>
    <div class="link">
        <a href="http://$PUBLIC_IP:8080" target="_blank">访问 Whoami 服务 (端口 8080)</a>
    </div>
    <div style="margin-top: 30px; font-size: 0.9em; opacity: 0.8;">
        <p>💡 Docker 容器管理: </p>
        <p>SSH:  ssh $USERNAME@$PUBLIC_IP</p>
        <p>命令: cd ~/docker && docker-compose -f docker-compose.example.yml up -d</p>
    </div>
</body>
</html>
EOF

# 创建抢占式实例监控脚本
cat > /home/$USERNAME/spot-monitor.sh <<'MONITOR'
#!/bin/bash

# 阿里云抢占式实例释放监控
LOG_FILE="/var/log/spot-monitor.log"

echo "$(date): 抢占式实例监控启动" >> "$LOG_FILE"

while true; do
    # 检查实例元数据，查看是否即将释放
    METADATA=$(curl -s --connect-timeout 2 http://100.100.100.200/latest/meta-data/instance/spot/termination-time 2>/dev/null)
    
    if [ -n "$METADATA" ] && [ "$METADATA" != "404" ] && [ "$METADATA" != "Not Found" ]; then
        echo "$(date): ⚠️ 抢占式实例即将被释放！释放时间: $METADATA" | tee -a "$LOG_FILE"
        
        # 执行清理操作
        echo "$(date): 开始清理 Docker 容器..." >> "$LOG_FILE"
        cd /home/$USERNAME/docker 2>/dev/null
        docker-compose down 2>/dev/null || true
        
        echo "$(date): 清理完成" >> "$LOG_FILE"
        
        # 可以在这里添加数据备份等操作
        # 例如:  rsync -av /data/ user@backup-server:/backups/
        
        break
    fi
    
    sleep 30
done
MONITOR

chmod +x /home/$USERNAME/spot-monitor.sh

# 创建 systemd 服务
cat > /etc/systemd/system/spot-monitor.service <<SERVICE
[Unit]
Description=Spot Instance Termination Monitor
After=network.target

[Service]
Type=simple
User=root
ExecStart=/home/$USERNAME/spot-monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# 可选：启用监控服务
# systemctl enable spot-monitor.service
# systemctl start spot-monitor.service

# 创建 README
cat > /home/$USERNAME/README.md <<'README'
# 阿里云抢占式实例 - Docker 环境

## 🚀 快速开始

```bash
# 检查 Docker
docker --version
docker compose version

# 运行示例
cd ~/docker
docker-compose -f docker-compose.example.yml up -d

# 查看容器
docker ps

# 查看日志
docker-compose logs -f
```

## 📊 抢占式实例监控

```bash
# 手动运行监控脚本
~/spot-monitor.sh &

# 或启用 systemd 服务
sudo systemctl enable spot-monitor.service
sudo systemctl start spot-monitor.service

# 查看监控日志
tail -f /var/log/spot-monitor.log
```

## 🐳 常用 Docker 命令

### 容器管理
```bash
dps          # docker ps
dpsa         # docker ps -a
dlog         # docker logs <container>
dexec        # docker exec -it <container> bash
```

### Docker Compose
```bash
dc           # docker-compose
dcup         # docker-compose up -d
dcdown       # docker-compose down
dclogs       # docker-compose logs -f
```

### 清理命令
```bash
# 停止所有容器
docker stop $(docker ps -q)

# 删除所有停止的容器
docker container prune -f

# 删除未使用的镜像
docker image prune -a -f

# 清理所有
docker system prune -a -f --volumes
```

## ⚠️ 注意事项

1. **数据持久化**: 重要数据请使用云盘或 OSS 存储
2. **定期备份**: 抢占式实例可能随时被回收
3. **监控实例**: 使用监控脚本提前保存数据
4. **成本优化**: 抢占式实例可节省 70-90% 成本

## 📁 目录结构

```
~/
├── projects/                    # 项目目录
├── docker/                      # Docker 配置
│   ├── docker-compose.example.yml
│   └── html/
│       └── index. html
├── spot-monitor.sh              # 监控脚本
└── README.md                    # 本文件
```

## 🔗 有用链接

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/)
- [阿里云容器镜像服务](https://cr.console.aliyun.com/)

## 🛠️ 故障排查

```bash
# 查看安装日志
sudo cat /var/log/setup-docker.log

# 查看 Docker 状态
sudo systemctl status docker

# 查看容器日志
docker logs <container_name>

# 重启 Docker
sudo systemctl restart docker
```
README

# 设置权限
chown -R $USERNAME:$USERNAME /home/$USERNAME

# 配置 bashrc
cat >> /home/$USERNAME/.bashrc <<'BASHRC'

# ==================== Docker 别名 ====================
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dlog='docker logs'
alias dexec='docker exec -it'
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias dclogs='docker-compose logs -f'

# ==================== 自定义提示符 ====================
export PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '

# ==================== 欢迎信息 ====================
cat << 'WELCOME'

🚀 ================================================
   阿里云抢占式实例 - Docker 环境就绪
   ================================================
   
   快速命令:  
   • docker --version
   • cd ~/docker && dcup
   • ~/spot-monitor.sh &
   
   查看 ~/README.md 了解更多
   ================================================

WELCOME
BASHRC

chown $USERNAME:$USERNAME /home/$USERNAME/.bashrc

# 配置 SSH 安全
echo "配置 SSH 安全设置..."
sed -i 's/^#*PasswordAuthentication. */PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# 重启 SSH 服务
systemctl restart sshd || systemctl restart ssh

echo 