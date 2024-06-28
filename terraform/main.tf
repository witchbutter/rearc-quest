data "aws_availability_zones" "available" {}

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

locals {
  region = "us-west-2"
  name   = "quest-${basename(path.cwd)}"

  vpc_cidr   = "10.20.0.0/16"
  azs        = slice(data.aws_availability_zones.available.names, 0, 3)
  dns_domain = "witchbutter.sh"

  container_name = "quest"

  tags = {
    Name  = local.name
    Owner = "witchbutter"
  }
}

################################################################################
# Cluster
################################################################################
resource "aws_ecs_cluster" "quest" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = local.tags
}

################################################################################
# Service
################################################################################
resource "aws_ecs_task_definition" "quest-service" {
  family                   = "service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  container_definitions = jsonencode([
    {
      name      = "quest"
      image     = "docker.io/witchbutter/rearc-quest:latest"
      essential = true
      portMappings = [
        {
          name          = "quest"
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "quest" {
  # Service
  name            = local.name
  cluster         = aws_ecs_cluster.quest.id
  task_definition = aws_ecs_task_definition.quest-service.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
    security_groups  = [aws_security_group.private.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.quest.arn
    container_name   = "quest"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = local.tags
}
