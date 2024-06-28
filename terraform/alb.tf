resource "aws_lb" "quest" {
  name               = "alb-${local.name}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = merge(
    local.tags,
    {
      "Name" = local.name
    }
  )
}

resource "aws_lb_listener" "redirecttohttps" {
  load_balancer_arn = aws_lb.quest.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.quest.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.wildcardcert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.quest.arn
  }

}

resource "aws_lb_target_group" "quest" {
  name        = "quest"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled = true
    matcher = "200"
    path    = "/secret_word"
  }
}

resource "aws_lb_listener_rule" "listener_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.quest.arn
  }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
  condition {
    host_header {
      values = [join(".", ["quest", local.dns_domain])]
    }
  }
}

resource "aws_route53_record" "quest" {
  name    = join(".", ["quest", local.dns_domain])
  type    = "CNAME"
  zone_id = data.aws_route53_zone.quest.id
  ttl     = 300
  records = [aws_lb.quest.dns_name]
}
