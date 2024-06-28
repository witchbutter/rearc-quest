module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway               = true
  single_nat_gateway               = true
  default_vpc_enable_dns_hostnames = true
  default_vpc_enable_dns_support   = true

  tags = local.tags
}

resource "aws_security_group" "public" {
  name   = "quest-public"
  vpc_id = module.vpc.vpc_id
  tags   = local.tags
}

resource "aws_security_group" "private" {
  name   = "quest-private"
  vpc_id = module.vpc.vpc_id
  tags   = local.tags
}

resource "aws_security_group" "loadbalancer" {
  name   = "quest-lb"
  vpc_id = module.vpc.vpc_id
  tags   = local.tags
}

resource "aws_security_group_rule" "permit-https-public" {
  from_port         = 443
  protocol          = "tcp"
  to_port           = 443
  type              = "ingress"
  security_group_id = aws_security_group.public.id
  cidr_blocks       = module.vpc.public_subnets_cidr_blocks
}

resource "aws_security_group_rule" "permit-http-public" {
  from_port         = 80
  protocol          = "tcp"
  to_port           = 80
  type              = "ingress"
  security_group_id = aws_security_group.public.id
  cidr_blocks       = module.vpc.public_subnets_cidr_blocks
}

resource "aws_security_group_rule" "permit-quest-from-public" {
  from_port                = 3000
  protocol                 = "tcp"
  to_port                  = 3000
  type                     = "ingress"
  security_group_id        = aws_security_group.public.id
  source_security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "permit-all-ingress-public-to-private" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "all"
  security_group_id = aws_security_group.private.id
  cidr_blocks       = module.vpc.public_subnets_cidr_blocks
}

resource "aws_security_group_rule" "permit-all-outbound-private" {
  type              = "egress"
  from_port         = -1
  to_port           = -1
  protocol          = "all"
  security_group_id = aws_security_group.private.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "permit-https-lb" {
  from_port         = 443
  protocol          = "tcp"
  to_port           = 443
  type              = "ingress"
  security_group_id = aws_security_group.loadbalancer.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "permit-http-lb" {
  from_port         = 80
  protocol          = "tcp"
  to_port           = 80
  type              = "ingress"
  security_group_id = aws_security_group.loadbalancer.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "permit-private-ingress-to-lb" {
  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = "all"
  security_group_id        = aws_security_group.loadbalancer.id
  source_security_group_id = aws_security_group.private.id
}

resource "aws_security_group_rule" "permit-public-ingress-to-lb" {
  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = "all"
  security_group_id        = aws_security_group.loadbalancer.id
  source_security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "permit-all-outbound-lb" {
  type              = "egress"
  from_port         = -1
  to_port           = -1
  protocol          = "all"
  security_group_id = aws_security_group.loadbalancer.id
  cidr_blocks       = ["0.0.0.0/0"]
}

