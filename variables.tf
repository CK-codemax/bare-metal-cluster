variable "region" {
  description = "AWS region"
  type        = string
}

variable "zones" {
  description = "Comma-separated list of availability zones"
  type        = string
}

variable "node_count" {
  default     = 2
  description = "Number of worker nodes"
}

variable "node_size" {
  default     = "t3.small"
  description = "EC2 instance type for worker nodes"
}

variable "control_plane_size" {
  default     = "t3.medium"
  description = "EC2 instance type for control plane"
}

variable "volume_size" {
  default = 12
  # for production, allow kops to create a larger volume
  description = "EBS volume size for nodes"
}

