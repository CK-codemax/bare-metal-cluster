# Get subnets in the default VPC filtered by the provided zones
data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = split(",", var.zones)
  }
}

#################################
# Network Load Balancer
#################################
resource "aws_lb" "k8s_nlb" {
  name                       = "k8s-master-nlb"
  internal                   = false
  load_balancer_type         = "network"
  subnets                    = data.aws_subnets.default_vpc.ids
  enable_deletion_protection = false

  tags = {
    Name = "k8s-master-nlb"
  }
}

#################################
# Target Group for Masters
#################################
resource "aws_lb_target_group" "k8s_masters_tg" {
  name        = "k8s-masters-tg"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = "6443"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
    timeout             = 5
  }
}

#################################
# Attach Master Instances
#################################
resource "aws_lb_target_group_attachment" "master_attachments" {
  count            = length(aws_instance.masters)
  target_group_arn = aws_lb_target_group.k8s_masters_tg.arn
  target_id        = aws_instance.masters[count.index].id
  port             = 6443
}

#################################
# Listener for NLB
#################################
resource "aws_lb_listener" "k8s_api_listener" {
  load_balancer_arn = aws_lb.k8s_nlb.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_masters_tg.arn
  }
}


