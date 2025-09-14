variable "region" {
  description = "AWS region"
  type        = string
}

variable "zones" {
  description = "Comma-separated list of availability zones"
  type        = string
}

variable "node_count" {
  default     = 3
  description = "Number of worker nodes"
}

variable "node_size" {
  default     = "t3.medium"
  description = "EC2 instance type for worker nodes"
}

variable "control_plane_size" {
  default     = "t3.medium"
  description = "EC2 instance type for control plane"
}

variable "volume_size" {
  default = 20
  description = "EBS volume size for nodes"
}
