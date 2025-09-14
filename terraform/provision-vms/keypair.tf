###############################
# TLS KEY PAIR - MASTERS
###############################
resource "tls_private_key" "master_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "master_keypair" {
  key_name   = "master-key"
  public_key = tls_private_key.master_key.public_key_openssh
}

resource "local_file" "master_private_key" {
  content         = tls_private_key.master_key.private_key_pem
  filename        = "${path.module}/master-key.pem"
  file_permission = "0400"
}

###############################
# TLS KEY PAIR - WORKERS
###############################
resource "tls_private_key" "worker_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "worker_keypair" {
  key_name   = "worker-key"
  public_key = tls_private_key.worker_key.public_key_openssh
}

resource "local_file" "worker_private_key" {
  content         = tls_private_key.worker_key.private_key_pem
  filename        = "${path.module}/worker-key.pem"
  file_permission = "0400"
}
