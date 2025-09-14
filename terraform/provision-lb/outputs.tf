#################################
# Output NLB DNS for Kubernetes API
#################################
output "k8s_api_endpoint" {
  description = "The NLB DNS name to use as Kubernetes API endpoint"
  value       = aws_lb.k8s_nlb.dns_name
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.k8s_nlb.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.k8s_masters_tg.arn
}
