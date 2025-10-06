# High-Availability Kubernetes Cluster on AWS

This project automates the deployment of a production-ready, highly available Kubernetes cluster on AWS using Terraform and Ansible. The cluster consists of 3 control-plane nodes and 3 worker nodes (6 nodes total) with proper load balancing and node naming.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet Gateway                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌─────────────────────────────────────────────────────────────┐
│                 Network Load Balancer                       │
│                  (k8s-master-nlb)                          │
│                    Port 6443                               │
└────────────┬────────────┬────────────┬─────────────────────┘
             │            │            │
    ┌────────▼───┐ ┌──────▼───┐ ┌──────▼───┐
    │  master1   │ │ master2  │ │ master3  │
    │ (Control   │ │ (Control │ │ (Control │
    │  Plane)    │ │  Plane)  │ │  Plane)  │
    └────────────┘ └──────────┘ └──────────┘
            
    ┌────────────┐ ┌──────────┐ ┌──────────┐
    │  worker1   │ │ worker2  │ │ worker3  │
    │            │ │          │ │          │
    └────────────┘ └──────────┘ └──────────┘
```

## ✨ Features

- **High Availability**: 3 control-plane nodes with etcd clustering
- **Load Balancing**: Network Load Balancer for API server
- **Proper Node Naming**: Nodes named as master1, master2, worker1, etc.
- **Automated Setup**: Complete automation with Terraform + Ansible
- **Production Ready**: Includes security groups, proper networking
- **Modular Design**: Separate contexts for VMs and Load Balancer
- **CNI Integration**: Calico network plugin pre-configured

## 🧱 HA Topology: Stacked etcd (kubeadm recommended pattern)

This cluster uses the stacked etcd topology, where each control-plane node runs both the Kubernetes control-plane components and a local etcd member in the same host.

## 📋 Prerequisites

### Required Tools
- **Terraform** >= 1.0
- **Ansible** >= 2.9
- **jq** (for JSON parsing)
- **AWS CLI** (configured with credentials)

### Installation Commands

**macOS:**
```bash
# Using Homebrew
brew install terraform ansible jq awscli

# Configure AWS CLI
aws configure
```

**Ubuntu/Debian:**
```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Ansible and jq
sudo apt install ansible jq awscli

# Configure AWS CLI
aws configure
```

### AWS Requirements
- Valid AWS account with programmatic access
- VPC with public subnets (uses default VPC by default)
- EC2 permissions for instance creation
- ELB permissions for load balancer creation

## 🚀 Quick Start

### Recommended Two-Step Deployment

**Step 1: Deploy Infrastructure**
```bash
# Clone and navigate to project
git clone <repository-url>
cd bare-metal-cluster

# Deploy AWS infrastructure (EC2 instances + Load Balancer)
./scripts/setup-infrastructure.sh
```

**Step 2: Update Inventory and Setup Cluster**
```bash
# Edit inventory file with actual IP addresses
nano ansible/inventory/hosts.yml

# Replace placeholders with actual IPs:
# YOUR_MASTER1_IP_HERE → 51.20.83.140
# YOUR_MASTER2_IP_HERE → 16.171.37.52
# etc.

# Test connectivity
cd ansible && ansible all -m ping

# Setup Kubernetes cluster
./scripts/setup-cluster.sh
```

### Alternative: Legacy Full Automation
```bash
# Full automated deployment (may have inventory issues with dynamic IPs)
./scripts/deploy-cluster.sh
```

## 🛠️ Deployment Methods

### Method 1: Using Shell Scripts (.sh) - Recommended

**Two-Step Deployment (Recommended):**
```bash
# Step 1: Deploy infrastructure
./scripts/setup-infrastructure.sh

# Step 2: Update inventory with actual IPs, then setup cluster
nano ansible/inventory/hosts.yml  # Update with actual IPs
./scripts/setup-cluster.sh
```

**Infrastructure Deployment Options:**
```bash
# Deploy both VMs and Load Balancer
./scripts/setup-infrastructure.sh

# Deploy only EC2 instances
./scripts/setup-infrastructure.sh vms

# Deploy only Load Balancer
./scripts/setup-infrastructure.sh lb
```

**Cluster Setup Options:**
```bash
# Full cluster setup
./scripts/setup-cluster.sh

# Install only prerequisites
./scripts/setup-cluster.sh prerequisites

# Setup only cluster (assumes prerequisites done)
./scripts/setup-cluster.sh cluster

# Test connectivity only
./scripts/setup-cluster.sh test
```

**Legacy Full Automation (May Have IP Issues):**
```bash
# Deploy everything with one command (uses generate-inventory.sh)
./scripts/deploy-cluster.sh

# Note: inventory generator was removed; update ansible/inventory/hosts.yml manually
```

**Cleanup Commands:**
```bash
# Full cleanup of all resources (Ansible 09 + infra destroy)
make delete-cluster

# Partial cleanup options
./scripts/cleanup-cluster.sh lb     # Remove only Load Balancer
./scripts/cleanup-cluster.sh vms    # Remove only EC2 instances
./scripts/cleanup-cluster.sh files  # Clean only generated files
```

### Method 2: Using Makefile

**Quick Commands:**
```bash
# Show all available commands
make help

# Recommended two-step deployment
make setup-infrastructure  # Setup infrastructure (VMs + LB)
# (Then update inventory manually)
make setup-cluster         # Run Ansible playbooks 01–08

# Legacy full deployment
make deploy                # Full deployment (may have IP issues)

# Individual components
make deploy-vms            # Deploy EC2 instances
make deploy-lb             # Deploy Load Balancer
```

**Management Commands:**
```bash
# Generate Ansible inventory
# (legacy) make inventory  # Note: generator script was removed

# Verify cluster health
make verify

# Test cluster functionality
make test

# Show cluster information
make info

# SSH to master1
make ssh-master1
```

**Cleanup Commands:**
```bash
# Full cleanup
make clean

# Partial cleanup
make clean-lb        # Remove only Load Balancer
make clean-vms       # Remove only EC2 instances
```

**Development Commands:**
```bash
# Check dependencies
make check-deps

# Format Terraform files
make fmt

# Validate Terraform configurations
make validate

# Lint Ansible playbooks
make lint
```

### Method 3: Using Ansible Directly (Playbooks 01–08, then 09 for cleanup)

**Prerequisites:** Ensure VMs and Load Balancer are deployed first.

**Full Cluster Setup:**
```bash
cd ansible

# Run all playbooks in sequence
# (No single main.yml runner; run individually as below)
```

**Individual Playbook Execution:**
```bash
cd ansible

# 1. Install prerequisites (containerd, kubetools)
ansible-playbook playbooks/01-install-prerequsites.yml

# 2. Verify prerequisites installation
ansible-playbook playbooks/02-verify-prerequisites.yml

# 3. Configure hostnames (master1, master2, etc.)
ansible-playbook playbooks/03-configure-hostnames.yml

# 4. Initialize first master node
ansible-playbook playbooks/04-init-first-master.yml

# 5. Install CNI (Calico)
ansible-playbook playbooks/05-setup-cni.yml

# 6. Join additional master nodes
ansible-playbook playbooks/06-join-other-masters.yml

# 7. Join worker nodes
ansible-playbook playbooks/07-join-workers.yml

# 8. Verify cluster health
ansible-playbook playbooks/08-verify-cluster.yml
```

**Ansible Ad-hoc Commands:**
```bash
cd ansible

# Test connectivity to all nodes
ansible all -i inventory/hosts.yml -m ping

# Check system status on all nodes
ansible all -i inventory/hosts.yml -m shell -a "systemctl status kubelet"

# Restart services if needed
ansible all -i inventory/hosts.yml -m systemd -a "name=kubelet state=restarted" --become

# Check containerd status
ansible all -i inventory/hosts.yml -m shell -a "systemctl status containerd" --become

# Run commands on specific groups
ansible masters -i inventory/hosts.yml -m shell -a "kubectl get nodes" --become
ansible workers -i inventory/hosts.yml -m shell -a "hostname"

# Check disk space on all nodes
ansible all -i inventory/hosts.yml -m shell -a "df -h"

# Update packages on all nodes
ansible all -i inventory/hosts.yml -m apt -a "update_cache=yes upgrade=yes" --become
```

**Ansible Inventory Management:**
```bash
# Copy provided template if needed
cp ansible/inventory/hosts-template.yml ansible/inventory/hosts.yml

# View current inventory
cat ansible/inventory/hosts.yml

# Test specific groups
ansible masters -i inventory/hosts.yml -m ping
ansible workers -i inventory/hosts.yml -m ping

# List all hosts
ansible all -i inventory/hosts.yml --list-hosts
```

**Advanced Ansible Operations:**
```bash
cd ansible

# Run playbooks with extra variables
ansible-playbook -i inventory/hosts.yml playbooks/04-init-first-master.yml -e "k8s_version=1.29.0"

# Run playbooks with increased verbosity
ansible-playbook -i inventory/hosts.yml playbooks/main.yml -v

# Run playbooks in check mode (dry run)
ansible-playbook -i inventory/hosts.yml playbooks/01-install-prerequisites.yml --check

# Run specific tasks by tags (if implemented)
ansible-playbook -i inventory/hosts.yml playbooks/main.yml --tags "install"

# Skip specific tasks by tags
ansible-playbook -i inventory/hosts.yml playbooks/main.yml --skip-tags "verify"

# Run playbooks on specific hosts
ansible-playbook -i inventory/hosts.yml playbooks/02-verify-prerequisites.yml --limit master1

# Run playbooks with different inventory
ansible-playbook -i custom-inventory.yml playbooks/main.yml
```

## 📁 Project Structure

```
bare-metal-cluster/
├── terraform/
│   ├── provision-vms/          # EC2 instances
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   ├── security-group.tf
│   │   ├── keypair.tf
│   │   └── terraform.tfvars
│   └── provision-lb/           # Network Load Balancer
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── provider.tf
│       └── terraform.tfvars
├── ansible/
│   ├── playbooks/
│   │   ├── 01-install-prerequsites.yml
│   │   ├── 02-verify-prerequisites.yml
│   │   ├── 03-configure-hostnames.yml
│   │   ├── 04-init-first-master.yml
│   │   ├── 05-setup-cni.yml
│   │   ├── 06-join-other-masters.yml
│   │   ├── 07-join-workers.yml
│   │   ├── 08-verify-cluster.yml
│   │   └── 09-clean-up-cluster.yml
│   ├── inventory/
│   │   └── hosts.yml          # Auto-generated
│   └── ansible.cfg
├── scripts/
│   ├── setup-infrastructure.sh  # Provision VMs and NLB
│   ├── setup-cluster.sh         # Run playbooks 01–08
│   ├── deploy-cluster.sh        # Legacy full automation
│   └── cleanup-cluster.sh       # Destroy infra and clean files
└── README.md
```

## ⚙️ Configuration

## ⚠️ Important: Dynamic IP Addresses

**AWS EC2 instances get new public IP addresses each time they are stopped and started.** This affects:

- **Ansible inventory** - IPs become invalid after stop/start
- **SSH access** - New IPs needed for connection
- **Load balancer targets** - May need updating

### Solutions:

1. **Use our two-step deployment** (Recommended)
   - Deploy infrastructure first
   - Manually update inventory with current IPs
   - Better control and reliability

2. **Use private IPs** (Production environments)
   - Connect via VPN or bastion host
   - Private IPs are static within VPC

3. **Use Elastic IPs** (Additional cost)
   - Static public IPs that persist
   - ~$3.65/month per IP when not attached to running instance

### Terraform Variables

Edit `terraform/provision-vms/terraform.tfvars`:

```hcl
# AWS region
region = "eu-north-1"

# Availability zones (comma-separated)
zones = "eu-north-1a,eu-north-1b,eu-north-1c"

# Number of worker nodes
node_count = 3

# Instance types
node_size = "t3.medium"
control_plane_size = "t3.medium"

# EBS volume size (in GB)
volume_size = 20
```

### Ansible Variables

Key variables in playbooks:
- `k8s_version`: Kubernetes version (default: 1.28.0)
- `pod_network_cidr`: Pod CIDR (default: 10.244.0.0/16)

## 🔧 Manual Deployment Steps

If you prefer to run each step manually:

### 1. Deploy Infrastructure

```bash
# Deploy EC2 instances
cd terraform/provision-vms
terraform init
terraform apply

# Generate Ansible inventory
cd ../../
./scripts/generate-inventory.sh
```

### 2. Install Prerequisites

```bash
cd ansible

# Install containerd and kubetools on all nodes
ansible-playbook playbooks/01-install-prerequisites.yml

# Verify installation
ansible-playbook playbooks/02-verify-prerequisites.yml
```

### 3. Deploy Load Balancer

```bash
cd ../terraform/provision-lb
terraform init
terraform apply

# Manually update ansible/inventory/hosts.yml with the LB DNS endpoint
cd ../../
```

### 4. Configure Cluster

```bash
cd ansible

# Configure hostnames
ansible-playbook playbooks/03-configure-hostnames.yml

# Initialize first master
ansible-playbook playbooks/04-init-first-master.yml

# Install CNI (Calico)
ansible-playbook playbooks/05-install-cni.yml

# Join additional masters
ansible-playbook playbooks/06-join-masters.yml

# Join worker nodes
ansible-playbook playbooks/07-join-workers.yml

# Verify cluster
ansible-playbook playbooks/08-verify-cluster.yml
```

## 🔍 Verification

### Check Cluster Status
```bash
# SSH to master1
ssh -i terraform/provision-vms/master-key.pem ubuntu@<master1-ip>

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check cluster info
kubectl cluster-info
```

### Expected Output
```bash
$ kubectl get nodes
NAME      STATUS   ROLES           AGE     VERSION
master1   Ready    control-plane   10m     v1.28.0
master2   Ready    control-plane   8m      v1.28.0
master3   Ready    control-plane   6m      v1.28.0
worker1   Ready    <none>         4m      v1.28.0
worker2   Ready    <none>         4m      v1.28.0
worker3   Ready    <none>         4m      v1.28.0
```

## 🧪 Testing the Cluster

Deploy a test application:

```bash
# Create a test deployment
kubectl create deployment test-nginx --image=nginx --replicas=3

# Expose as service
kubectl expose deployment test-nginx --port=80 --type=NodePort

# Check deployment
kubectl get pods,svc
```

## 🧹 Cleanup

### Full Cleanup (Playbook 09 + infra deletion)
```bash
make delete-cluster
```

### Partial Cleanup
```bash
# Remove only Load Balancer
./scripts/cleanup-cluster.sh lb

# Remove only EC2 instances
./scripts/cleanup-cluster.sh vms

# Clean only generated files
./scripts/cleanup-cluster.sh files
```

## 🔧 Troubleshooting

### Common Issues

**1. Instances not reachable**
```bash
# Check if instances are running
cd terraform/provision-vms
terraform show

# Test connectivity manually
cd ../../ansible
ansible all -m ping
```

**2. Kubeadm init fails**
```bash
# Check logs on master1
ssh -i terraform/provision-vms/master-key.pem ubuntu@<master1-ip>
sudo journalctl -u kubelet -f
```

**3. Nodes not joining**
```bash
# Check join commands
cat ansible/join-commands/master-join-command.sh
cat ansible/join-commands/worker-join-command.sh

# Regenerate if needed
ssh master1 "kubeadm token create --print-join-command"
```

**4. CNI issues**
```bash
# Check Calico pods
kubectl get pods -n kube-system -l k8s-app=calico-node

# Restart Calico if needed
kubectl delete pods -n kube-system -l k8s-app=calico-node
```

### Log Locations
- **Kubelet logs**: `sudo journalctl -u kubelet`
- **Containerd logs**: `sudo journalctl -u containerd`
- **Kubeadm logs**: `/var/log/kubeadm.log`

## 📝 Notes

- The cluster uses Calico CNI with BGP networking
- Load balancer health checks target port 6443 (Kubernetes API)
- All nodes have proper hostnames (master1, master2, etc.)
- SSH keys are automatically generated and stored in Terraform directories
- The cluster is configured for production use with proper security groups

## ✅ Clear Setup Instructions

1) Setup infrastructure (creates 6-node HA footprint + NLB):
```bash
make setup-infrastructure
```

2) Update Ansible inventory with real IPs and LB DNS:
```bash
cp ansible/inventory/hosts-template.yml ansible/inventory/hosts.yml # if missing
nano ansible/inventory/hosts.yml
```

Inventory guidance (edit these values):
```yaml
# ansible/inventory/hosts.yml
all:
  vars:
    ansible_user: ubuntu
    control_plane_endpoint: YOUR_LOAD_BALANCER_DNS_HERE:6443
  children:
    masters:
      hosts:
        master1:
          ansible_host: YOUR_MASTER1_IP_HERE
        master2:
          ansible_host: YOUR_MASTER2_IP_HERE
        master3:
          ansible_host: YOUR_MASTER3_IP_HERE
    workers:
      hosts:
        worker1:
          ansible_host: YOUR_WORKER1_IP_HERE
        worker2:
          ansible_host: YOUR_WORKER2_IP_HERE
        worker3:
          ansible_host: YOUR_WORKER3_IP_HERE
```
Where to find values:
- Replace YOUR_MASTER[1-3]_IP_HERE and YOUR_WORKER[1-3]_IP_HERE with the public IPs printed at the end of `make setup-infrastructure`.
- Replace YOUR_LOAD_BALANCER_DNS_HERE with the printed Load Balancer DNS name.

3) Verify connectivity:
```bash
cd ansible && ansible all -i inventory/hosts.yml -m ping
```

4) Setup the cluster (runs playbooks 01–08 in order):
```bash
make setup-cluster
```

5) Verify on a control-plane node:
```bash
ssh -i terraform/provision-vms/master-key.pem ubuntu@<master1-ip>
kubectl get nodes -o wide
```

6) Delete the cluster when done:
```bash
make delete-cluster
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Calico Documentation](https://docs.projectcalico.org/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CKA Repository](https://github.com/sandervanvugt/cka) - Source of setup scripts
