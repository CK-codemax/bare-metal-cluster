#################################
# Outputs for SSH access
#################################

# Master node public IPs
output "master_public_ips" {
  description = "Public IPs of Kubernetes master nodes"
  value       = aws_instance.masters[*].public_ip
}

# Worker node public IPs
output "worker_public_ips" {
  description = "Public IPs of Kubernetes worker nodes"
  value       = aws_instance.workers[*].public_ip
}

# SSH command for master nodes
output "ssh_master_commands" {
  description = "SSH commands to access master nodes"
  value = [
    for ip in aws_instance.masters[*].public_ip :
    "ssh -i ${path.module}/master-key.pem ubuntu@${ip}"
  ]
}

# SSH command for worker nodes
output "ssh_worker_commands" {
  description = "SSH commands to access worker nodes"
  value = [
    for ip in aws_instance.workers[*].public_ip :
    "ssh -i ${path.module}/worker-key.pem ubuntu@${ip}"
  ]
}

#################################
# Output NLB DNS for Kubernetes API
#################################
output "k8s_api_endpoint" {
  description = "The NLB DNS name to use as Kubernetes API endpoint"
  value       = aws_lb.k8s_nlb.dns_name
}
