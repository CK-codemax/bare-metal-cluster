#!/bin/bash

# Setup Kubernetes cluster (assumes infrastructure is already deployed)
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
    exit 1
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    command -v ansible >/dev/null 2>&1 || error "Ansible is required but not installed"
    
    success "All dependencies are installed"
}

# Check inventory
check_inventory() {
    log "Checking inventory configuration..."
    
    if [ ! -f "$PROJECT_ROOT/ansible/inventory/hosts.yml" ]; then
        error "Inventory file not found at ansible/inventory/hosts.yml"
    fi
    
    # Check if inventory still has placeholder values
    if grep -q "YOUR_.*_IP_HERE\|YOUR_LOAD_BALANCER_DNS_HERE" "$PROJECT_ROOT/ansible/inventory/hosts.yml"; then
        error "Inventory file contains placeholder values. Please update ansible/inventory/hosts.yml with actual IP addresses."
    fi
    
    success "Inventory file is configured"
}

# Test connectivity
test_connectivity() {
    log "Testing connectivity to all hosts..."
    
    cd "$PROJECT_ROOT/ansible"
    
    if ansible all -i inventory/hosts.yml -m ping > /dev/null 2>&1; then
        success "All hosts are reachable!"
    else
        error "Some hosts are not reachable. Please check your inventory file and ensure instances are running."
    fi
}

# Install prerequisites
install_prerequisites() {
    log "Installing Kubernetes prerequisites..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook -i inventory/hosts.yml playbooks/01-install-prerequisites.yml
    
    success "Prerequisites installed"
}

# Verify prerequisites
verify_prerequisites() {
    log "Verifying prerequisites..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook -i inventory/hosts.yml playbooks/02-verify-prerequisites.yml

    success "Prerequisites verified"
}

# Configure hostnames
configure_hostnames() {
    log "Configuring hostnames..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook -i inventory/hosts.yml playbooks/03-configure-hostnames.yml

    success "Hostnames configured"
}

# Initialize first master
init_first_master() {
    log "Initializing first master node..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook -i inventory/hosts.yml playbooks/04-init-first-master.yml

    success "First master initialized"
}

# Install CNI
install_cni() {
    log "Installing CNI (Calico)..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook -i inventory/hosts.yml playbooks/05-install-cni.yml

    success "CNI installed"
}

# Join additional masters
join_masters() {
    log "Joining additional master nodes..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook -i inventory/hosts.yml playbooks/06-join-masters.yml

    success "Additional masters joined"
}

# Join workers
join_workers() {
    log "Joining worker nodes..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook -i inventory/hosts.yml playbooks/07-join-workers.yml

    success "Worker nodes joined"
}

# Verify cluster
verify_cluster() {
    log "Verifying cluster..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook -i inventory/hosts.yml playbooks/08-verify-cluster.yml
    
    success "Cluster verification completed"
}

# Display cluster info
display_cluster_info() {
    log "Displaying cluster information..."
    
    echo ""
    echo "🎉 Kubernetes HA cluster setup completed!"
    echo ""
    echo "🔑 SSH Access:"
    echo "   Master nodes: ssh -i terraform/provision-vms/master-key.pem ubuntu@<master_ip>"
    echo "   Worker nodes: ssh -i terraform/provision-vms/worker-key.pem ubuntu@<worker_ip>"
    
    echo ""
    echo "📋 Cluster Management:"
    echo "   1. SSH to any master node to manage the cluster"
    echo "   2. Check cluster status: kubectl get nodes"
    echo "   3. Check system pods: kubectl get pods -A"
    echo "   4. Deploy applications: kubectl apply -f your-app.yaml"
    
    echo ""
    success "🎊 Cluster setup completed successfully!"
}

# Main setup function
main() {
    echo "☸️  Starting Kubernetes Cluster Setup"
    echo "====================================="
    
    check_dependencies
    check_inventory
    test_connectivity
    install_prerequisites
    verify_prerequisites
    configure_hostnames
    init_first_master
    install_cni
    join_masters
    join_workers
    verify_cluster
    display_cluster_info
}

# Handle script arguments
case "${1:-}" in
    "prerequisites")
        check_dependencies
        check_inventory
        test_connectivity
        install_prerequisites
        verify_prerequisites
        ;;
    "cluster")
        configure_hostnames
        init_first_master
        install_cni
        join_masters
        join_workers
        verify_cluster
        ;;
    "test")
        check_inventory
        test_connectivity
        ;;
    "")
        main
        ;;
    *)
        echo "Usage: $0 [prerequisites|cluster|test]"
        echo "  prerequisites - Install only prerequisites"
        echo "  cluster      - Setup only cluster (assumes prerequisites done)"
        echo "  test         - Test connectivity only"
        echo "  (no arg)     - Full cluster setup"
        exit 1
        ;;
esac
