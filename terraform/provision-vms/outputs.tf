#################################
# Outputs for Ansible inventory
#################################

# Master node details
output "master_instances" {
  description = "Master node details for Ansible"
  value = [
    for i, instance in aws_instance.masters : {
      name       = "master${i + 1}"
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
      instance_id = instance.id
    }
  ]
}

# Worker node details
output "worker_instances" {
  description = "Worker node details for Ansible"
  value = [
    for i, instance in aws_instance.workers : {
      name       = "worker${i + 1}"
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
      instance_id = instance.id
    }
  ]
}

# SSH key paths
output "master_key_path" {
  description = "Path to master nodes SSH key"
  value       = "${path.module}/master-key.pem"
}

output "worker_key_path" {
  description = "Path to worker nodes SSH key"
  value       = "${path.module}/worker-key.pem"
}

# Combined instances for easy access
output "all_instances" {
  description = "All instances for Ansible inventory"
  value = {
    masters = [
      for i, instance in aws_instance.masters : {
        name       = "master${i + 1}"
        public_ip  = instance.public_ip
        private_ip = instance.private_ip
        instance_id = instance.id
        role       = "master"
      }
    ]
    workers = [
      for i, instance in aws_instance.workers : {
        name       = "worker${i + 1}"
        public_ip  = instance.public_ip
        private_ip = instance.private_ip
        instance_id = instance.id
        role       = "worker"
      }
    ]
  }
}
