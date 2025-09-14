#!/bin/bash

# Deploy HA Kubernetes cluster on AWS
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
    
    command -v terraform >/dev/null 2>&1 || error "Terraform is required but not installed"
    command -v ansible >/dev/null 2>&1 || error "Ansible is required but not installed"
    command -v jq >/dev/null 2>&1 || error "jq is required but not installed"
    
    success "All dependencies are installed"
}

# Step 1: Deploy VMs
deploy_vms() {
    log "Step 1: Deploying EC2 instances..."
    
    cd "$PROJECT_ROOT/terraform/provision-vms"
    
    if [ ! -f "terraform.tfstate" ]; then
        log "Initializing Terraform..."
        terraform init
    fi
    
    log "Planning Terraform deployment..."
    terraform plan
    
    log "Applying Terraform configuration..."
    terraform apply -auto-approve
    
    success "EC2 instances deployed successfully"
}

# Step 2: Generate Ansible inventory
generate_inventory() {
    log "Step 2: Generating Ansible inventory..."
    
    "$SCRIPT_DIR/generate-inventory.sh"
    
    success "Ansible inventory generated"
}

# Step 3: Wait for instances to be ready
wait_for_instances() {
    log "Step 3: Waiting for instances to be ready..."
    
    cd "$PROJECT_ROOT/ansible"
    
    # Wait up to 5 minutes for all instances to be reachable
    local retries=30
    local delay=10
    
    for ((i=1; i<=retries; i++)); do
        log "Attempt $i/$retries: Testing connectivity..."
        
        if ansible all -m ping > /dev/null 2>&1; then
            success "All instances are reachable!"
            return 0
        fi
        
        if [ $i -lt $retries ]; then
            log "Some instances not ready yet, waiting ${delay}s..."
            sleep $delay
        fi
    done
    
    error "Instances are not reachable after $((retries * delay)) seconds"
}

# Step 4: Install prerequisites
install_prerequisites() {
    log "Step 4: Installing Kubernetes prerequisites..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook playbooks/01-install-prerequisites.yml
    
    success "Prerequisites installed"
}

# Step 5: Verify prerequisites
verify_prerequisites() {
    log "Step 5: Verifying prerequisites..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook playbooks/02-verify-prerequisites.yml
    
    success "Prerequisites verified"
}

# Step 6: Deploy Load Balancer
deploy_load_balancer() {
    log "Step 6: Deploying Network Load Balancer..."
    
    cd "$PROJECT_ROOT/terraform/provision-lb"
    
    if [ ! -f "terraform.tfstate" ]; then
        log "Initializing Terraform for Load Balancer..."
        terraform init
    fi
    
    log "Planning Load Balancer deployment..."
    terraform plan
    
    log "Applying Load Balancer configuration..."
    terraform apply -auto-approve
    
    success "Network Load Balancer deployed successfully"
}

# Step 7: Update inventory with Load Balancer
update_inventory_with_lb() {
    log "Step 7: Updating inventory with Load Balancer endpoint..."
    
    "$SCRIPT_DIR/generate-inventory.sh"
    
    success "Inventory updated with Load Balancer endpoint"
}

# Step 8: Configure hostnames
configure_hostnames() {
    log "Step 8: Configuring hostnames..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook playbooks/03-configure-hostnames.yml
    
    success "Hostnames configured"
}

# Step 9: Initialize first master
init_first_master() {
    log "Step 9: Initializing first master node..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook playbooks/04-init-first-master.yml
    
    success "First master initialized"
}

# Step 10: Install CNI
install_cni() {
    log "Step 10: Installing CNI (Calico)..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook playbooks/05-install-cni.yml
    
    success "CNI installed"
}

# Step 11: Join additional masters
join_masters() {
    log "Step 11: Joining additional master nodes..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook playbooks/06-join-masters.yml
    
    success "Additional masters joined"
}

# Step 12: Join workers
join_workers() {
    log "Step 12: Joining worker nodes..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook playbooks/07-join-workers.yml
    
    success "Worker nodes joined"
}

# Step 13: Verify cluster
verify_cluster() {
    log "Step 13: Verifying cluster..."
    
    cd "$PROJECT_ROOT/ansible"
    
    ansible-playbook playbooks/08-verify-cluster.yml
    
    success "Cluster verification completed"
}

# Step 14: Display cluster info
display_cluster_info() {
    log "Step 14: Displaying cluster information..."
    
    echo ""
    echo "🎉 Kubernetes HA cluster deployed successfully!"
    echo ""
    echo "📊 Cluster Information:"
    echo "======================"
    
    # Get Load Balancer endpoint
    cd "$PROJECT_ROOT/terraform/provision-lb"
    LB_ENDPOINT=$(terraform output -raw k8s_api_endpoint 2>/dev/null || echo "Not available")
    
    echo "🔗 API Server Endpoint: $LB_ENDPOINT:6443"
    echo ""
    
    # Get node information
    cd "$PROJECT_ROOT/terraform/provision-vms"
    echo "🖥️  Master Nodes:"
    terraform output -json master_instances | jq -r '.[] | "   • \(.name): \(.public_ip) (private: \(.private_ip))"'
    
    echo ""
    echo "👷 Worker Nodes:"
    terraform output -json worker_instances | jq -r '.[] | "   • \(.name): \(.public_ip) (private: \(.private_ip))"'
    
    echo ""
    echo "🔑 SSH Access:"
    echo "   Master nodes: ssh -i terraform/provision-vms/master-key.pem ubuntu@<master_ip>"
    echo "   Worker nodes: ssh -i terraform/provision-vms/worker-key.pem ubuntu@<worker_ip>"
    
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Connect to master1: ssh -i terraform/provision-vms/master-key.pem ubuntu@\$(terraform output -raw master_instances | jq -r '.[0].public_ip')"
    echo "   2. Check cluster status: kubectl get nodes"
    echo "   3. Deploy applications: kubectl apply -f your-app.yaml"
}

# Main deployment function
main() {
    echo "🚀 Starting Kubernetes HA Cluster Deployment"
    echo "=============================================="
    
    check_dependencies
    deploy_vms
    generate_inventory
    wait_for_instances
    install_prerequisites
    verify_prerequisites
    deploy_load_balancer
    update_inventory_with_lb
    configure_hostnames
    init_first_master
    install_cni
    join_masters
    join_workers
    verify_cluster
    display_cluster_info
    
    echo ""
    success "🎊 Deployment completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    "vms")
        check_dependencies
        deploy_vms
        generate_inventory
        ;;
    "lb")
        deploy_load_balancer
        update_inventory_with_lb
        ;;
    "cluster")
        wait_for_instances
        install_prerequisites
        verify_prerequisites
        configure_hostnames
        init_first_master
        install_cni
        join_masters
        join_workers
        verify_cluster
        display_cluster_info
        ;;
    "")
        main
        ;;
    *)
        echo "Usage: $0 [vms|lb|cluster]"
        echo "  vms     - Deploy only EC2 instances"
        echo "  lb      - Deploy only Load Balancer"
        echo "  cluster - Setup only Kubernetes cluster (assumes VMs and LB exist)"
        echo "  (no arg) - Full deployment"
        exit 1
        ;;
esac
