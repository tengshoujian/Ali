#!/bin/bash

################################################################################
# 系统初始化脚本
# 功能：创建新用户、配置SSH密钥、安装Docker和Docker Compose
################################################################################

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以root运行
if [[ $EUID -ne 0 ]]; then
   log_error "此脚本必须以root权限运行"
   exit 1
fi

################################################################################
# 配置参数 - 请根据实际情况修改
################################################################################

# 新用户名
NEW_USER="deployuser"

# 用户密码（可选，留空则不设置密码，仅使用SSH密钥登录）
USER_PASSWORD=""

# SSH公钥 - 请替换为您的实际公钥
SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...  your-email@example.com"

# Docker Compose版本
DOCKER_COMPOSE_VERSION="2.24.5"

################################################################################
# 1. 创建新用户
################################################################################

log_info "开始创建用户:  $NEW_USER"

if id "$NEW_USER" &>/dev/null; then
    log_warn "用户 $NEW_USER 已存在，跳过创建"
else
    # 创建用户并创建家目录
    useradd -m -s /bin/bash "$NEW_USER"
    log_info "用户 $NEW_USER 创建成功"
    
    # 如果设置了密码，则配置密码
    if [ -n "$USER_PASSWORD" ]; then
        echo "$NEW_USER:$USER_PASSWORD" | chpasswd
        log_info "用户密码已设置"
    fi
    
    # 添加用户到sudo组（可选）
    usermod -aG sudo "$NEW_USER" 2>/dev/null || usermod -aG wheel "$NEW_USER" 2>/dev/null || true
    log_info "用户已添加到管理员组"
fi

################################################################################
# 2. 配置SSH密钥
################################################################################

log_info "配置SSH密钥"

USER_HOME="/home/$NEW_USER"
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# 创建. ssh目录
if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    log_info "创建 . ssh 目录"
fi

# 创建或更新authorized_keys文件
if [ !  -f "$AUTHORIZED_KEYS" ]; then
    touch "$AUTHORIZED_KEYS"
    log_info "创建 authorized_keys 文件"
fi

# 检查公钥是否已存在
if grep -qF "$SSH_PUBLIC_KEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
    log_warn "SSH公钥已存在，跳过添加"
else
    echo "$SSH_PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
    log_info "SSH公钥已添加"
fi

# 设置正确的权限
chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "$NEW_USER:$NEW_USER" "$SSH_DIR"
log_info "SSH目录权限已设置"

################################################################################
# 3. 安装Docker
################################################################################

log_info "开始安装Docker"

# 检测操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    log_error "无法检测操作系统"
    exit 1
fi

# 检查Docker是否已安装
if command -v docker &> /dev/null; then
    log_warn "Docker已安装，版本:  $(docker --version)"
else
    case $OS in
        ubuntu|debian)
            log_info "检测到 Ubuntu/Debian 系统"
            
            # 更新包索引
            apt-get update
            
            # 安装必要的包
            apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            
            # 添加Docker官方GPG密钥
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            
            # 设置Docker仓库
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # 安装Docker Engine
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
            
        centos|rhel|rocky|almalinux)
            log_info "检测到 CentOS/RHEL 系统"
            
            # 安装必要的包
            yum install -y yum-utils
            
            # 添加Docker仓库
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            # 安装Docker Engine
            yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
            
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    
    log_info "Docker安装成功"
fi

# 启动Docker服务
systemctl start docker
systemctl enable docker
log_info "Docker服务已启动并设置为开机自启"

# 将用户添加到docker组
if groups "$NEW_USER" | grep -q docker; then
    log_warn "用户 $NEW_USER 已在docker组中"
else
    usermod -aG docker "$NEW_USER"
    log_info "用户 $NEW_USER 已添加到docker组"
fi

################################################################################
# 4. 安装Docker Compose (standalone)
################################################################################

log_info "安装Docker Compose独立版本"

# 检查docker compose插件
if docker compose version &> /dev/null; then
    log_info "Docker Compose插件已安装:  $(docker compose version)"
fi

# 安装standalone版本的docker-compose
if command -v docker-compose &> /dev/null; then
    log_warn "docker-compose已安装，版本: $(docker-compose --version)"
else
    log_info "下载Docker Compose v${DOCKER_COMPOSE_VERSION}"
    
    curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    
    chmod +x /usr/local/bin/docker-compose
    
    # 创建软链接（可选）
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    
    log_info "Docker Compose安装成功:  $(docker-compose --version)"
fi

################################################################################
# 5. 验证安装
################################################################################

log_info "验证安装..."

echo ""
echo "=========================================="
echo "安装完成！系统信息："
echo "=========================================="
echo "用户名: $NEW_USER"
echo "用户主目录: $USER_HOME"
echo "Docker版本: $(docker --version)"
echo "Docker Compose插件:  $(docker compose version 2>/dev/null || echo '未安装')"
echo "Docker Compose独立版:  $(docker-compose --version 2>/dev/null || echo '未安装')"
echo "Docker服务状态: $(systemctl is-active docker)"
echo "=========================================="
echo ""

log_info "提示:  用户 $NEW_USER 需要重新登录才能使用docker组权限"
log_info "或者使用以下命令切换:  su - $NEW_USER"

# 测试Docker（可选）
log_info "运行Docker测试..."
if docker run --rm hello-world &> /dev/null; then
    log_info "Docker测试通过 ✓"
else
    log_warn "Docker测试失败，请检查配置"
fi

echo ""
log_info "安装脚本执行完成！"