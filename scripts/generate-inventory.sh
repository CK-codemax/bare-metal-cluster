#!/bin/bash

# Generate Ansible inventory from Terraform outputs
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/provision-vms"
INVENTORY_DIR="$PROJECT_ROOT/ansible/inventory"
LB_TERRAFORM_DIR="$PROJECT_ROOT/terraform/provision-lb"

# Check if Terraform state exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    echo "Error: Terraform state not found. Please run 'terraform apply' first in $TERRAFORM_DIR"
    exit 1
fi

# Create inventory directory if it doesn't exist
mkdir -p "$INVENTORY_DIR"
mkdir -p "$PROJECT_ROOT/ansible/join-commands"

# Get Terraform outputs
cd "$TERRAFORM_DIR"
TERRAFORM_OUTPUT=$(terraform output -json)

# Extract instance information
MASTER_IPS=$(echo "$TERRAFORM_OUTPUT" | jq -r '.master_instances.value[] | "\(.name):\n      ansible_host: \(.public_ip)"')
WORKER_IPS=$(echo "$TERRAFORM_OUTPUT" | jq -r '.worker_instances.value[] | "\(.name):\n      ansible_host: \(.public_ip)"')

# Get Load Balancer DNS name if available
LB_DNS_NAME=""
if [ -f "$LB_TERRAFORM_DIR/terraform.tfstate" ]; then
    cd "$LB_TERRAFORM_DIR"
    LB_OUTPUT=$(terraform output -json 2>/dev/null || echo '{}')
    LB_DNS_NAME=$(echo "$LB_OUTPUT" | jq -r '.k8s_api_endpoint.value // empty')
fi

# Generate simple Ansible inventory
cat > "$INVENTORY_DIR/hosts.yml" << EOF
all:
  hosts:
$(echo "$MASTER_IPS" | sed 's/^/    /')
$(echo "$WORKER_IPS" | sed 's/^/    /')
  children:
    masters:
      hosts:
$(echo "$TERRAFORM_OUTPUT" | jq -r '.master_instances.value[] | .name' | sed 's/^/        /' | sed 's/$/:/') 
    workers:
      hosts:
$(echo "$TERRAFORM_OUTPUT" | jq -r '.worker_instances.value[] | .name' | sed 's/^/        /' | sed 's/$/:/') 
    k8s_cluster:
      children:
        masters:
        workers:
      vars:
        ansible_user: ubuntu
        ansible_ssh_private_key_file: ../terraform/provision-vms/master-key.pem
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
        lb_dns_name: "${LB_DNS_NAME:-PLACEHOLDER_LB_ENDPOINT}"
EOF

echo "✅ Ansible inventory generated at $INVENTORY_DIR/hosts.yml"

# Display the inventory
echo ""
echo "📋 Generated inventory:"
cat "$INVENTORY_DIR/hosts.yml"

# Test connectivity
echo ""
echo "🔗 Testing connectivity to all hosts..."
cd "$PROJECT_ROOT/ansible"

if ansible all -m ping > /dev/null 2>&1; then
    echo "✅ All hosts are reachable!"
else
    echo "⚠️  Some hosts may not be reachable yet. This is normal if instances just started."
    echo "   Run 'ansible all -m ping' to test connectivity manually."
fi
