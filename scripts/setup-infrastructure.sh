#!/bin/bash

# Deploy only infrastructure (VMs and Load Balancer)
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

# Step 2: Deploy Load Balancer
deploy_load_balancer() {
    log "Step 2: Deploying Network Load Balancer..."
    
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

# Step 3: Generate inventory template
generate_inventory_template() {
    log "Step 3: Setting up inventory template..."
    
    # Copy template to hosts.yml if it doesn't exist
    if [ ! -f "$PROJECT_ROOT/ansible/inventory/hosts.yml" ]; then
        cp "$PROJECT_ROOT/ansible/inventory/hosts-template.yml" "$PROJECT_ROOT/ansible/inventory/hosts.yml"
        log "Inventory template copied to hosts.yml"
    fi
    
    success "Inventory template ready"
}

# Step 4: Display instance information
display_instance_info() {
    log "Step 4: Displaying instance information..."
    
    echo ""
    echo "🎉 Infrastructure deployed successfully!"
    echo ""
    echo "📊 Instance Information:"
    echo "======================="
    
    # Get instance IPs from Terraform
    cd "$PROJECT_ROOT/terraform/provision-vms"
    
    if [ -f "terraform.tfstate" ]; then
        echo ""
        echo "🖥️  Master Nodes:"
        terraform output -json 2>/dev/null | jq -r '
            if .master_instances then
                .master_instances.value[] | "   • \(.name): \(.public_ip) (private: \(.private_ip))"
            else
                empty
            end' 2>/dev/null || echo "   Unable to fetch master node IPs"
        
        echo ""
        echo "👷 Worker Nodes:"
        terraform output -json 2>/dev/null | jq -r '
            if .worker_instances then
                .worker_instances.value[] | "   • \(.name): \(.public_ip) (private: \(.private_ip))"
            else
                empty
            end' 2>/dev/null || echo "   Unable to fetch worker node IPs"
    fi
    
    # Get Load Balancer endpoint
    cd "$PROJECT_ROOT/terraform/provision-lb"
    if [ -f "terraform.tfstate" ]; then
        echo ""
        LB_ENDPOINT=$(terraform output -raw k8s_api_endpoint 2>/dev/null || echo "Not available")
        echo "🔗 Load Balancer Endpoint: $LB_ENDPOINT:6443"
    fi
    
    echo ""
    echo "📋 Next Steps:"
    echo "=============="
    echo "1. Update the inventory file with actual IPs:"
    echo "   nano ansible/inventory/hosts.yml"
    echo ""
    echo "2. Update these placeholders:"
    echo "   • YOUR_MASTER1_IP_HERE → actual master1 public IP"
    echo "   • YOUR_MASTER2_IP_HERE → actual master2 public IP"
    echo "   • YOUR_MASTER3_IP_HERE → actual master3 public IP"
    echo "   • YOUR_WORKER1_IP_HERE → actual worker1 public IP"
    echo "   • YOUR_WORKER2_IP_HERE → actual worker2 public IP"
    echo "   • YOUR_WORKER3_IP_HERE → actual worker3 public IP"
    echo "   • YOUR_LOAD_BALANCER_DNS_HERE → $LB_ENDPOINT"
    echo ""
    echo "3. Test connectivity:"
    echo "   cd ansible && ansible all -m ping"
    echo ""
    echo "4. Setup Kubernetes cluster:"
    echo "   ./scripts/setup-cluster.sh"
    echo ""
    
    success "🎊 Infrastructure deployment completed!"
}

# Main deployment function
main() {
    echo "🚀 Starting Infrastructure Deployment"
    echo "====================================="
    
    check_dependencies
    deploy_vms
    deploy_load_balancer
    generate_inventory_template
    display_instance_info
}

# Handle script arguments
case "${1:-}" in
    "vms")
        check_dependencies
        deploy_vms
        ;;
    "lb")
        deploy_load_balancer
        ;;
    "")
        main
        ;;
    *)
        echo "Usage: $0 [vms|lb]"
        echo "  vms     - Deploy only EC2 instances"
        echo "  lb      - Deploy only Load Balancer"
        echo "  (no arg) - Full infrastructure deployment"
        exit 1
        ;;
esac
