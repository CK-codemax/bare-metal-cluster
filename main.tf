#################################
# Master Nodes (3 nodes, t3.medium, Ubuntu 22.04)
#################################
resource "aws_instance" "masters" {
  count                  = 3
  ami                    = data.aws_ami.ubuntu_jammy.id
  instance_type          = var.control_plane_size
  key_name               = aws_key_pair.master_keypair.key_name
  vpc_security_group_ids = [aws_security_group.ha_sg.id]

  availability_zone = element(split(",", var.zones), count.index)

  tags = {
    Name = "k8s-master-${count.index + 1}"
    Role = "master"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y git

              # Clone the repo
              git clone https://github.com/sandervanvugt/cka.git /home/ubuntu/cka

              # Make scripts executable
              chmod +x /home/ubuntu/cka/setup-container.sh
              chmod +x /home/ubuntu/cka/setup-kubetools.sh

              # Run scripts sequentially
              /home/ubuntu/cka/setup-container.sh
              /home/ubuntu/cka/setup-kubetools.sh
              EOF
}

#################################
# Worker Nodes (3 nodes, t3.medium, Ubuntu 22.04)
#################################
resource "aws_instance" "workers" {
  count                  = var.node_count
  ami                    = data.aws_ami.ubuntu_jammy.id
  instance_type          = var.node_size
  key_name               = aws_key_pair.worker_keypair.key_name
  vpc_security_group_ids = [aws_security_group.ha_sg.id]

  availability_zone = element(split(",", var.zones), count.index)

  tags = {
    Name = "k8s-worker-${count.index + 1}"
    Role = "worker"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y git

              # Clone the repo
              git clone https://github.com/sandervanvugt/cka.git /home/ubuntu/cka

              # Make scripts executable
              chmod +x /home/ubuntu/cka/setup-container.sh
              chmod +x /home/ubuntu/cka/setup-kubetools.sh

              # Run scripts sequentially
              /home/ubuntu/cka/setup-container.sh
              /home/ubuntu/cka/setup-kubetools.sh
              EOF
}

