#!/bin/bash

# Cleanup HA Kubernetes cluster resources
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Cleanup Load Balancer
cleanup_lb() {
    log "Cleaning up Load Balancer..."
    
    cd "$PROJECT_ROOT/terraform/provision-lb"
    
    if [ -f "terraform.tfstate" ]; then
        terraform destroy -auto-approve
        success "Load Balancer destroyed"
    else
        warning "No Load Balancer state found"
    fi
}

# Cleanup VMs
cleanup_vms() {
    log "Cleaning up EC2 instances..."
    
    cd "$PROJECT_ROOT/terraform/provision-vms"
    
    if [ -f "terraform.tfstate" ]; then
        terraform destroy -auto-approve
        success "EC2 instances destroyed"
    else
        warning "No VM state found"
    fi
}

# Cleanup generated files
cleanup_generated_files() {
    log "Cleaning up generated files..."
    
    # Remove SSH keys
    rm -f "$PROJECT_ROOT/terraform/provision-vms/master-key.pem"
    rm -f "$PROJECT_ROOT/terraform/provision-vms/worker-key.pem"
    
    # Remove Ansible inventory
    rm -f "$PROJECT_ROOT/ansible/inventory/hosts.yml"
    
    # Remove join commands
    rm -rf "$PROJECT_ROOT/ansible/join-commands"
    
    # Remove Terraform state backups
    find "$PROJECT_ROOT" -name "*.tfstate.backup" -delete
    find "$PROJECT_ROOT" -name ".terraform.lock.hcl" -delete
    
    success "Generated files cleaned up"
}

# Main cleanup function
main() {
    echo "🧹 Starting Kubernetes HA Cluster Cleanup"
    echo "=========================================="
    
    read -p "Are you sure you want to destroy all resources? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Cleanup cancelled"
        exit 0
    fi
    
    cleanup_lb
    cleanup_vms
    cleanup_generated_files
    
    success "🎊 Cleanup completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    "lb")
        cleanup_lb
        ;;
    "vms")
        cleanup_vms
        ;;
    "files")
        cleanup_generated_files
        ;;
    "")
        main
        ;;
    *)
        echo "Usage: $0 [lb|vms|files]"
        echo "  lb    - Destroy only Load Balancer"
        echo "  vms   - Destroy only EC2 instances"
        echo "  files - Clean only generated files"
        echo "  (no arg) - Full cleanup"
        exit 1
        ;;
esac
