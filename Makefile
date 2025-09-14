# Kubernetes HA Cluster on AWS - Makefile
.PHONY: help deploy deploy-vms deploy-lb deploy-cluster clean clean-lb clean-vms inventory verify test

# Default target
help:
	@echo "🚀 Kubernetes HA Cluster on AWS"
	@echo "================================"
	@echo ""
	@echo "Available targets:"
	@echo "  deploy       - Full deployment (VMs + LB + Cluster)"
	@echo "  deploy-vms   - Deploy only EC2 instances"
	@echo "  deploy-lb    - Deploy only Load Balancer"
	@echo "  deploy-cluster - Setup only Kubernetes cluster"
	@echo "  inventory    - Generate Ansible inventory"
	@echo "  verify       - Verify cluster status"
	@echo "  test         - Run cluster tests"
	@echo "  clean        - Full cleanup"
	@echo "  clean-lb     - Remove only Load Balancer"
	@echo "  clean-vms    - Remove only EC2 instances"
	@echo "  help         - Show this help"

# Full deployment
deploy:
	@echo "🚀 Starting full deployment..."
	./scripts/deploy-cluster.sh

# Deploy VMs only
deploy-vms:
	@echo "🖥️  Deploying EC2 instances..."
	./scripts/deploy-cluster.sh vms

# Deploy Load Balancer only
deploy-lb:
	@echo "⚖️  Deploying Load Balancer..."
	./scripts/deploy-cluster.sh lb

# Setup Kubernetes cluster only
deploy-cluster:
	@echo "☸️  Setting up Kubernetes cluster..."
	./scripts/deploy-cluster.sh cluster

# Generate Ansible inventory
inventory:
	@echo "📋 Generating Ansible inventory..."
	./scripts/generate-inventory.sh

# Verify cluster
verify:
	@echo "🔍 Verifying cluster status..."
	cd ansible && ansible-playbook playbooks/08-verify-cluster.yml

# Test cluster functionality
test:
	@echo "🧪 Testing cluster..."
	@echo "Connecting to master1 and running tests..."
	@cd terraform/provision-vms && \
	MASTER1_IP=$$(terraform output -json master_instances | jq -r '.[0].public_ip') && \
	ssh -i master-key.pem -o StrictHostKeyChecking=no ubuntu@$$MASTER1_IP \
		'kubectl get nodes && kubectl get pods -A && kubectl run test-pod --image=nginx --rm -it --restart=Never --command -- /bin/echo "Cluster test successful!"'

# Full cleanup
clean:
	@echo "🧹 Starting full cleanup..."
	./scripts/cleanup-cluster.sh

# Clean Load Balancer only
clean-lb:
	@echo "🗑️  Removing Load Balancer..."
	./scripts/cleanup-cluster.sh lb

# Clean VMs only
clean-vms:
	@echo "🗑️  Removing EC2 instances..."
	./scripts/cleanup-cluster.sh vms

# Check prerequisites
check-deps:
	@echo "🔍 Checking dependencies..."
	@which terraform >/dev/null || (echo "❌ Terraform not found" && exit 1)
	@which ansible >/dev/null || (echo "❌ Ansible not found" && exit 1)
	@which jq >/dev/null || (echo "❌ jq not found" && exit 1)
	@which aws >/dev/null || (echo "❌ AWS CLI not found" && exit 1)
	@echo "✅ All dependencies found"

# Show cluster info
info:
	@echo "📊 Cluster Information"
	@echo "====================="
	@if [ -f terraform/provision-lb/terraform.tfstate ]; then \
		cd terraform/provision-lb && \
		echo "🔗 API Endpoint: $$(terraform output -raw k8s_api_endpoint):6443"; \
	fi
	@echo ""
	@if [ -f terraform/provision-vms/terraform.tfstate ]; then \
		cd terraform/provision-vms && \
		echo "🖥️  Master Nodes:" && \
		terraform output -json master_instances | jq -r '.[] | "   • \(.name): \(.public_ip)"' && \
		echo "" && \
		echo "👷 Worker Nodes:" && \
		terraform output -json worker_instances | jq -r '.[] | "   • \(.name): \(.public_ip)"'; \
	fi

# SSH to master1
ssh-master1:
	@cd terraform/provision-vms && \
	MASTER1_IP=$$(terraform output -json master_instances | jq -r '.[0].public_ip') && \
	echo "🔐 Connecting to master1 ($$MASTER1_IP)..." && \
	ssh -i master-key.pem -o StrictHostKeyChecking=no ubuntu@$$MASTER1_IP

# Development targets
fmt:
	@echo "🔧 Formatting Terraform files..."
	@cd terraform/provision-vms && terraform fmt
	@cd terraform/provision-lb && terraform fmt

validate:
	@echo "✅ Validating Terraform configurations..."
	@cd terraform/provision-vms && terraform validate
	@cd terraform/provision-lb && terraform validate

lint:
	@echo "🔍 Linting Ansible playbooks..."
	@cd ansible && ansible-lint playbooks/ || true
