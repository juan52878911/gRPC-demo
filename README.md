# Rancher Cluster Automation

Automated deployment of a Rancher Kubernetes cluster using Terraform, Ansible, and Multipass VMs.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Manual Deployment](#manual-deployment)
- [Cluster Management](#cluster-management)
- [Troubleshooting](#troubleshooting)
- [Architecture Details](#architecture-details)

## 🎯 Overview

This project provides a fully automated infrastructure-as-code solution for deploying a Rancher management platform with Kubernetes clusters on local VMs using Multipass. The entire stack is provisioned and configured automatically with a single command.

**Key Features:**
- ✅ Fully automated deployment (infrastructure + configuration)
- ✅ Rancher server with custom cluster creation
- ✅ Multi-node Kubernetes cluster (1 master + N workers)
- ✅ Idempotent playbooks (safe to re-run)
- ✅ Custom labels and annotations
- ✅ Development-ready in ~15 minutes

## 🏗️ Architecture

### Component Stack

```
┌─────────────────────────────────────────────────────┐
│                    Rancher UI                       │
│              https://<master-ip>                    │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│              Rancher Master Node                    │
│  - Rancher Server (Docker container)               │
│  - Manages k3s-cluster via API                     │
└─────────────────────────────────────────────────────┘
                         ↓
        ┌────────────────┴────────────────┐
        ↓                                  ↓
┌──────────────────┐            ┌──────────────────┐
│   Worker Node 1  │            │   Worker Node 2  │
│  - K3s Agent     │            │  - K3s Agent     │
│  - rancher-      │            │  - rancher-      │
│    system-agent  │            │    system-agent  │
└──────────────────┘            └──────────────────┘
```

### Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **IaaS** | Multipass | Local VM provisioning |
| **IaC** | Terraform | Infrastructure as Code |
| **Configuration** | Ansible | Configuration management |
| **Container Runtime** | Docker | Rancher container runtime |
| **Orchestration** | Rancher | Kubernetes management platform |
| **Kubernetes** | K3s | Lightweight Kubernetes distribution |
| **Init System** | cloud-init | VM bootstrapping |

## 📦 Prerequisites

### Required Software

- **macOS** (ARM64 or x86_64)
- **Multipass** 1.11.0+
- **Terraform** 1.0.0+
- **Ansible** 2.19.0+
- **SSH** key pair

### Installation

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install --cask multipass
brew install terraform ansible

# Verify installations
multipass version
terraform version
ansible --version
```

## 🚀 Quick Start

### One-Command Deployment

```bash
# Clone the repository
git clone <repository-url>
cd terraform

# Run automated setup
./setup.sh
```

**This will:**
1. ✅ Provision VMs (1 master + 2 workers)
2. ✅ Install Docker, Python, system packages via cloud-init
3. ✅ Deploy Rancher server on master
4. ✅ Create custom K3s cluster via Rancher API
5. ✅ Register all worker nodes automatically
6. ✅ Display access credentials

**Total time:** ~10-15 minutes

### Access Rancher

After deployment completes:

```
URL: https://<master-ip>
Username: admin
Password: AdminPassword123
```

Access the dashboard and navigate to **Cluster Management** → **k3s-cluster** to see your nodes.

## ⚙️ Configuration

### Terraform Variables

Edit `variables.tf` or create `terraform.tfvars`:

```hcl
# Master node resources
master_cpus   = 2
master_memory = "4G"
master_disk   = "20G"

# Worker node resources
worker_cpus   = 2
worker_memory = "4G"
worker_disk   = "20G"
worker_count  = 2

# SSH key (defaults to ~/.ssh/id_rsa.pub)
ssh_public_key_path = "~/.ssh/id_rsa.pub"
```

### Ansible Variables

Edit `ansible/roles/master/defaults/main.yml`:

```yaml
# Rancher configuration
rancher_version: "latest"
rancher_admin_password: "AdminPassword123"  # Change for production!

# Cluster configuration
rancher_cluster_name: "k3s-cluster"
rancher_cluster_description: "K3s cluster created via Ansible automation"

# Cluster labels
rancher_cluster_labels:
  environment: "development"
  provisioner: "ansible"
  cluster_type: "k3s"
  distribution: "k3s"

# Cluster annotations
rancher_cluster_annotations:
  created_by: "rancher-ansible-automation"
  cluster_purpose: "Development and testing with K3s"
  kubernetes_distribution: "k3s"
```

## 🔧 Manual Deployment

### Step-by-Step

#### 1. Provision Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

#### 2. Configure Rancher Master

```bash
cd ansible
ansible-playbook -i inventory.ini site.yml --tags master
```

This will:
- Install Rancher container
- Set admin password
- Create k3s-cluster
- Generate registration command

#### 3. Register Workers

```bash
ansible-playbook -i inventory.ini site.yml --tags workers
```

This will:
- Fetch registration command from master
- Install rancher-system-agent on each worker
- Register workers to the cluster

## 📊 Cluster Management

### Useful Commands

```bash
# List all VMs
multipass list

# Connect to master
multipass shell rancher-master

# Connect to worker
multipass shell worker-1

# View Rancher logs
multipass exec rancher-master -- docker logs -f rancher

# View system-agent logs on worker
multipass exec worker-1 -- journalctl -u rancher-system-agent -f

# Check Docker status
ansible all -i ansible/inventory.ini -m shell -a "systemctl status docker"

# Test connectivity
ansible all -i ansible/inventory.ini -m ping
```

### Terraform Operations

```bash
# View outputs
terraform output

# Get master IP
terraform output -raw master_ip

# Show current state
terraform show

# Destroy everything
terraform destroy -auto-approve
```

### Ansible Operations

```bash
# Run only master configuration
ansible-playbook -i inventory.ini site.yml --tags master

# Run only worker registration
ansible-playbook -i inventory.ini site.yml --tags workers

# Run with verbose output
ansible-playbook -i inventory.ini site.yml -vvv

# Check cluster status
ansible master -i inventory.ini -m shell -a "docker ps | grep rancher"
```

## 🐛 Troubleshooting

### Common Issues

#### VMs not starting
```bash
# Check Multipass status
multipass list

# Restart Multipass daemon
sudo launchctl stop com.canonical.multipassd
sudo launchctl start com.canonical.multipassd
```

#### Cloud-init not finishing
```bash
# Check cloud-init status
multipass exec rancher-master -- cloud-init status

# View cloud-init logs
multipass exec rancher-master -- cat /var/log/cloud-init-output.log
```

#### Rancher not accessible
```bash
# Check Rancher container
multipass exec rancher-master -- docker ps | grep rancher

# View Rancher logs
multipass exec rancher-master -- docker logs rancher

# Check firewall
multipass exec rancher-master -- netstat -tlnp | grep 443
```

#### Workers not registering
```bash
# Check registration command exists
multipass exec rancher-master -- cat /home/ubuntu/cluster-registration-cmd.sh

# Manually execute registration on worker
multipass exec worker-1 -- bash /home/ubuntu/cluster-registration-cmd.sh

# Check system-agent service
multipass exec worker-1 -- systemctl status rancher-system-agent

# View agent logs
multipass exec worker-1 -- journalctl -u rancher-system-agent -n 100
```

#### Cattle ID persistence error
This usually means insufficient permissions. Ensure:
- Ansible is using `become: yes` for worker tasks
- The registration command includes `sudo`

### Clean State

To start fresh:

```bash
# Destroy all infrastructure
terraform destroy -auto-approve

# Delete and purge all Multipass VMs
multipass delete --all --purge

# Clean Terraform state
rm -rf .terraform terraform.tfstate*

# Re-initialize
terraform init
```

## 📐 Architecture Details

### Deployment Flow

```
1. Terraform Phase
   ├─ Render cloud-init templates with SSH keys
   ├─ Create Multipass VMs (master + workers)
   ├─ Cloud-init installs: Docker, Python3, packages
   └─ Generate Ansible inventory with VM IPs

2. Ansible Master Phase
   ├─ Deploy Rancher container
   ├─ Wait for Rancher API ready
   ├─ Login with bootstrap password
   ├─ Change admin password
   ├─ Create custom cluster via API
   ├─ Wait for registration token
   └─ Save registration command to file

3. Ansible Worker Phase
   ├─ Fetch registration command from master
   ├─ Execute: curl | sudo sh -s - --etcd --controlplane --worker
   ├─ Install rancher-system-agent
   ├─ Agent connects to Rancher
   └─ K3s provisioned automatically
```

### File Structure

```
terraform/
├── README.md                       # This file
├── setup.sh                        # Automated deployment script
├── main.tf                         # Main Terraform configuration
├── variables.tf                    # Input variables
├── outputs.tf                      # Output values
├── cloud-init-scripts/
│   ├── master.tpl                  # Master cloud-init template
│   └── worker.tpl                  # Worker cloud-init template
└── ansible/
    ├── ansible.cfg                 # Ansible configuration
    ├── inventory.ini               # Generated by Terraform
    ├── inventory.ini.template      # Inventory template
    ├── requirements.yml            # Ansible collections
    ├── site.yml                    # Main playbook
    └── roles/
        ├── master/                 # Rancher installation role
        │   ├── tasks/main.yml
        │   └── defaults/main.yml
        └── worker/                 # Worker registration role
            ├── tasks/main.yml
            └── defaults/main.yml
```

### Network Architecture

```
Host Machine (macOS)
    ↓
Multipass Bridge Network
    ↓
┌─────────────────────────────────────┐
│ VM Network (192.168.64.0/24)       │
│                                     │
│  rancher-master: 192.168.64.X      │
│  worker-1:       192.168.64.Y      │
│  worker-2:       192.168.64.Z      │
└─────────────────────────────────────┘
```

All VMs are accessible from the host via their assigned IPs.

### Security Considerations

⚠️ **This setup is for DEVELOPMENT/TESTING only**

- Uses self-signed certificates (browser warnings expected)
- Default admin password is in plaintext
- No firewall rules configured
- SSH keys without passphrases recommended for automation
- `--insecure` flag used for curl (bypasses cert validation)

**For production:**
- Use proper SSL certificates
- Store secrets in Ansible Vault or secret manager
- Implement network segmentation
- Enable firewalls and security groups
- Use strong, unique passwords
- Enable audit logging

## 📝 Notes

### Cluster Type: Imported (Custom)

The cluster is created as "Imported" type in Rancher because:
- It allows manual node registration
- Doesn't require CAPI webhooks (which can fail in local setups)
- Workers install K3s via rancher-system-agent
- Full Kubernetes functionality despite "Imported" label

The cluster **runs real K3s** - labels confirm the distribution:
```yaml
labels:
  cluster_type: "k3s"
  distribution: "k3s"
```

### Why Not Provisioning API?

RKE2/K3s provisioning clusters via `/v1/provisioning.cattle.io.clusters` require:
- CAPI (Cluster API) webhooks to be fully operational
- Rancher system services completely initialized
- More complex setup prone to timing issues

For local development, Custom/Imported clusters are more reliable.

### Idempotency

All Ansible playbooks are idempotent:
- ✅ Safe to re-run without side effects
- ✅ Detects existing resources (cluster, agents)
- ✅ Skips already-completed steps
- ✅ Only changes what's necessary

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- **Rancher** - Kubernetes management platform
- **Canonical Multipass** - Lightweight VM manager
- **HashiCorp Terraform** - Infrastructure as Code
- **Ansible** - Configuration management
- **K3s** - Lightweight Kubernetes by Rancher

---

**Built with ❤️ for Kubernetes automation**
