#!/bin/bash

###############################################################################
# Setup Script for User, SSH, Docker, and Docker Compose
# 
# This script:
# 1. Creates a new user with appropriate home directory
# 2. Configures SSH access with authorized_keys
# 3. Installs Docker
# 4. Installs Docker Compose
# 5. Configures Docker to start on boot
# 6. Adds the new user to the docker group
#
# Usage: sudo bash setup.sh <username> <ssh_public_key>
# Example: sudo bash setup.sh deployuser "ssh-rsa AAAAB3NzaC1yc2EA..."
###############################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check arguments
if [ $# -lt 2 ]; then
    print_error "Usage: $0 <username> <ssh_public_key>"
    print_error "Example: $0 deployuser \"ssh-rsa AAAAB3NzaC1yc2EA...\""
    exit 1
fi

USERNAME="$1"
SSH_PUBLIC_KEY="$2"

print_info "Starting setup for user: $USERNAME"

###############################################################################
# 1. User Setup
###############################################################################

print_info "Creating user $USERNAME..."

# Check if user already exists
if id "$USERNAME" &>/dev/null; then
    print_warning "User $USERNAME already exists, skipping user creation"
else
    # Create user with home directory
    useradd -m -s /bin/bash "$USERNAME"
    print_info "User $USERNAME created successfully"
fi

###############################################################################
# 2. SSH Configuration
###############################################################################

print_info "Configuring SSH access for $USERNAME..."

USER_HOME=$(eval echo ~$USERNAME)
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Create .ssh directory if it doesn't exist
if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    print_info "Created .ssh directory"
else
    print_warning ".ssh directory already exists"
fi

# Set correct permissions for .ssh directory
chmod 700 "$SSH_DIR"
chown "$USERNAME:$USERNAME" "$SSH_DIR"
print_info "Set permissions on .ssh directory (700)"

# Create or update authorized_keys file
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    touch "$AUTHORIZED_KEYS"
    print_info "Created authorized_keys file"
fi

# Add SSH public key if it doesn't already exist
if grep -qF "$SSH_PUBLIC_KEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
    print_warning "SSH public key already exists in authorized_keys"
else
    echo "$SSH_PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
    print_info "Added SSH public key to authorized_keys"
fi

# Set correct permissions for authorized_keys
chmod 600 "$AUTHORIZED_KEYS"
chown "$USERNAME:$USERNAME" "$AUTHORIZED_KEYS"
print_info "Set permissions on authorized_keys (600)"

###############################################################################
# 3. Docker Installation
###############################################################################

print_info "Installing Docker..."

# Check if Docker is already installed
if command -v docker &>/dev/null; then
    print_warning "Docker is already installed ($(docker --version))"
else
    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi

    print_info "Detected OS: $OS $VERSION_ID"

    # Install Docker based on OS
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        print_info "Installing Docker on Ubuntu/Debian..."
        
        # Update package index
        apt-get update -y
        
        # Install required packages
        apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        # Set up Docker repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        print_info "Docker installed successfully"
        
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]] || [[ "$OS" == "fedora" ]]; then
        print_info "Installing Docker on CentOS/RHEL/Fedora..."
        
        # Install required packages
        yum install -y yum-utils
        
        # Set up Docker repository
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        # Install Docker Engine
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        print_info "Docker installed successfully"
        
    else
        print_error "Unsupported OS: $OS"
        print_error "Please install Docker manually"
        exit 1
    fi
fi

###############################################################################
# 4. Configure Docker Service
###############################################################################

print_info "Configuring Docker service..."

# Enable Docker to start on boot
systemctl enable docker

# Start Docker if not running
if systemctl is-active --quiet docker; then
    print_warning "Docker service is already running"
else
    systemctl start docker
    print_info "Docker service started"
fi

print_info "Docker service configured to start on boot"

###############################################################################
# 5. Add User to Docker Group
###############################################################################

print_info "Adding $USERNAME to docker group..."

# Check if user is already in docker group
if groups "$USERNAME" | grep -q '\bdocker\b'; then
    print_warning "User $USERNAME is already in docker group"
else
    usermod -aG docker "$USERNAME"
    print_info "User $USERNAME added to docker group"
    print_info "User will need to log out and back in for group changes to take effect"
fi

###############################################################################
# 6. Docker Compose Installation
###############################################################################

print_info "Installing Docker Compose..."

# Fallback version if API call fails
FALLBACK_COMPOSE_VERSION="v2.29.0"

# Check if docker-compose is already installed
if command -v docker-compose &>/dev/null; then
    print_warning "Docker Compose is already installed ($(docker-compose --version))"
else
    # Get latest version of Docker Compose
    DOCKER_COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' || true)
    
    if [ -z "$DOCKER_COMPOSE_VERSION" ]; then
        print_warning "Could not determine latest Docker Compose version, using $FALLBACK_COMPOSE_VERSION"
        DOCKER_COMPOSE_VERSION="$FALLBACK_COMPOSE_VERSION"
    fi
    
    print_info "Installing Docker Compose $DOCKER_COMPOSE_VERSION..."
    
    # Download Docker Compose
    COMPOSE_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    if curl -fsSL "$COMPOSE_URL" -o /usr/local/bin/docker-compose; then
        # Make it executable
        chmod +x /usr/local/bin/docker-compose
        
        # Create symbolic link if needed
        if [ ! -f /usr/bin/docker-compose ]; then
            ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi
        
        print_info "Docker Compose installed successfully"
    else
        print_error "Failed to download Docker Compose from $COMPOSE_URL"
        exit 1
    fi
fi

###############################################################################
# 7. Verification
###############################################################################

print_info "Verifying installation..."

echo ""
print_info "========================================="
print_info "Installation Summary"
print_info "========================================="

# Check user
if id "$USERNAME" &>/dev/null; then
    echo -e "${GREEN}✓${NC} User $USERNAME exists"
else
    echo -e "${RED}✗${NC} User $USERNAME does not exist"
fi

# Check SSH directory
if [ -d "$SSH_DIR" ] && [ "$(stat -c %a $SSH_DIR)" == "700" ]; then
    echo -e "${GREEN}✓${NC} SSH directory configured correctly (permissions: 700)"
else
    echo -e "${RED}✗${NC} SSH directory not configured correctly"
fi

# Check authorized_keys
if [ -f "$AUTHORIZED_KEYS" ] && [ "$(stat -c %a $AUTHORIZED_KEYS)" == "600" ]; then
    echo -e "${GREEN}✓${NC} authorized_keys configured correctly (permissions: 600)"
else
    echo -e "${RED}✗${NC} authorized_keys not configured correctly"
fi

# Check Docker
if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓${NC} Docker installed: $DOCKER_VERSION"
else
    echo -e "${RED}✗${NC} Docker not installed"
fi

# Check Docker service
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓${NC} Docker service is running"
else
    echo -e "${RED}✗${NC} Docker service is not running"
fi

# Check Docker enabled on boot
if systemctl is-enabled --quiet docker; then
    echo -e "${GREEN}✓${NC} Docker enabled on boot"
else
    echo -e "${RED}✗${NC} Docker not enabled on boot"
fi

# Check user in docker group
if groups "$USERNAME" | grep -q '\bdocker\b'; then
    echo -e "${GREEN}✓${NC} User $USERNAME in docker group"
else
    echo -e "${RED}✗${NC} User $USERNAME not in docker group"
fi

# Check Docker Compose
if command -v docker-compose &>/dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    echo -e "${GREEN}✓${NC} Docker Compose installed: $COMPOSE_VERSION"
else
    echo -e "${RED}✗${NC} Docker Compose not installed"
fi

print_info "========================================="
echo ""
print_info "Setup completed successfully!"
print_info "Note: User $USERNAME will need to log out and back in for docker group changes to take effect"
print_info "You can test SSH access with: ssh $USERNAME@<server-ip>"
print_info "You can test Docker with: docker run hello-world"
echo ""
