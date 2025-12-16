# Ali
Ali terraform

## Overview

This repository contains Terraform configuration for provisioning Alicloud ECS instances and a setup script for configuring the instances with Docker and user access.

## Components

### Terraform Configuration

- `main.tf` - Main infrastructure configuration
- `variables.tf` - Variable definitions
- `provider.tf` - Alicloud provider configuration
- `output.tf` - Output values (public IPs)

### Setup Script

The `setup.sh` script automates the configuration of newly provisioned ECS instances with:

- User creation with SSH access
- Docker installation and configuration
- Docker Compose installation

## Usage

### 1. Provision Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 2. Configure Instance

After provisioning, use the setup script to configure the instance:

```bash
# Copy the script to your instance
scp setup.sh root@<instance-ip>:~

# SSH into the instance
ssh root@<instance-ip>

# Run the setup script
sudo bash setup.sh <username> "<ssh-public-key>"
```

**Example:**

```bash
sudo bash setup.sh deployuser "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDExample..."
```

### Setup Script Features

The setup script (`setup.sh`) performs the following tasks:

1. **User Setup**
   - Creates a new user with home directory
   - Sets up `.ssh` directory with correct permissions (700)
   - Creates `authorized_keys` file with correct permissions (600)
   - Adds the provided SSH public key

2. **Docker Installation**
   - Installs Docker Engine
   - Configures Docker to start on boot
   - Adds the user to the docker group for non-root access
   - Supports Ubuntu/Debian and CentOS/RHEL/Fedora

3. **Docker Compose Installation**
   - Downloads and installs the latest Docker Compose
   - Makes it available system-wide

4. **Verification**
   - Provides a summary of all installations
   - Verifies correct permissions and configurations

### Script Properties

- **Idempotent**: Safe to run multiple times
- **Error handling**: Exits on errors with clear messages
- **Security**: Follows SSH and file permission best practices
- **Compatibility**: Supports multiple Linux distributions

### After Setup

Once the setup script completes:

1. You can SSH into the instance as the new user:
   ```bash
   ssh <username>@<instance-ip>
   ```

2. The user can run Docker commands without sudo:
   ```bash
   docker run hello-world
   docker-compose --version
   ```

   **Note**: The user must log out and back in for docker group changes to take effect.

## Variables

Key variables you can customize in `variables.tf`:

- `instance_type` - ECS instance type (default: ecs.e-c1m2.large)
- `image_id` - OS image ID (default: Ubuntu 18.04)
- `region` - Alicloud region (default: cn-huhehaote)
- `internet_bandwidth` - Internet bandwidth in Mbps (default: 10)
- `instance_name` - Instance name (default: tf-sample)
- `ecs_count` - Number of instances to create (default: 1)

## Security Considerations

- Change the default password in `variables.tf` before deploying
- Use SSH key authentication instead of passwords when possible
- Review and restrict security group rules as needed
- Keep Docker and Docker Compose updated
- Follow the principle of least privilege when creating users

## License

This project is provided as-is for infrastructure automation purposes.
