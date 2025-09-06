# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Security group for HA Kubernetes cluster
resource "aws_security_group" "ha_sg" {
  name        = "k8s-ha-sg"
  description = "Security group for Kubernetes HA cluster"
  vpc_id      = data.aws_vpc.default.id # Use default VPC

  # SSH for provisioning
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with your IP
  }

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For testing; restrict in production
  }

  # etcd communication (between masters)
  ingress {
    from_port = 2379
    to_port   = 2380
    protocol  = "tcp"
    self      = true # Allow traffic within the same SG (masters)
  }

  # Kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
    cidr_blocks = ["10.0.0.0/16"] # Adjust to your VPC CIDR
  }

  # NodePort range (workers)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict in production
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-ha-sg"
  }
}

