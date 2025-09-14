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

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  # Set hostname during boot
  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname master${count.index + 1}
              echo "127.0.0.1 master${count.index + 1}" >> /etc/hosts
              apt-get update -y
              apt-get install -y python3 python3-pip
              EOF

  tags = {
    Name = "k8s-master-${count.index + 1}"
    Role = "master"
    Hostname = "master${count.index + 1}"
  }
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

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  # Set hostname during boot
  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname worker${count.index + 1}
              echo "127.0.0.1 worker${count.index + 1}" >> /etc/hosts
              apt-get update -y
              apt-get install -y python3 python3-pip
              EOF

  tags = {
    Name = "k8s-worker-${count.index + 1}"
    Role = "worker"
    Hostname = "worker${count.index + 1}"
  }
}
