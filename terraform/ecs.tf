# SecurityGroup
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "service_a" {
  name   = "${local.app_name}-service-a"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.app_name}-service-a"
  }
}

resource "aws_security_group" "service_b" {
  name   = "${local.app_name}-service-b"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.app_name}-service-b"
  }
}

# aws_security_group_rule
# https://registry.terraform.io/providers/hashicorp/aws/3.42.0/docs/resources/security_group_rule
resource "aws_security_group_rule" "a_from_b" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.service_b.id
  security_group_id        = aws_security_group.service_a.id
}

resource "aws_security_group_rule" "a_from_any" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = local.allowed_ips
  security_group_id = aws_security_group.service_a.id
}

resource "aws_security_group_rule" "b_from_a" {
  type              = "ingress"
  from_port         = 8081
  to_port           = 8081
  protocol          = "tcp"
  source_security_group_id = aws_security_group.service_a.id
  security_group_id = aws_security_group.service_b.id
}


resource "aws_security_group_rule" "b_from_any" {
  type              = "ingress"
  from_port         = 8081
  to_port           = 8081
  protocol          = "tcp"
  cidr_blocks       = local.allowed_ips
  security_group_id = aws_security_group.service_b.id
}

# ECS Connect
resource "aws_service_discovery_http_namespace" "qiita" {
  name = "qiita"
}

# ECS Cluster
# https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html
resource "aws_ecs_cluster" "main" {
  name = local.app_name

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.qiita.arn
  }
}

# ECS Cluster Capacity Providers
# https://registry.terraform.io/providers/hashicorp/aws/4.7.0/docs/resources/ecs_cluster_capacity_providers
resource "aws_ecs_cluster_capacity_providers" "provider" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}

# IAM Role
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role
# ECSがタスクを実行するために必要なIAMロール・ポリシーの設定が必要
resource "aws_iam_role" "ecs_task_execution_role" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  description = "Allows ECS tasks to call AWS services on your behalf."
  name        = "qiitaEcsTaskExecutionRole"
  path        = "/"
}


# ECS Task Definition
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition.html
resource "aws_ecs_task_definition" "service_a" {
  family                   = "${local.app_name}_service_a"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::${var.user_id}:role/ecsTaskExecutionRole"
  container_definitions = jsonencode([
    {
      name         = "service_a"
      image        = local.images.service_a
      cpu          = 256
      memory       = 512
      essential    = true
      network_mode = "awsvpc"
      portMappings = [
        {
          name          = "service_a"
          containerPort = 8080
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        {
          name  = "SERVICE_B_URL"
          value = "http://service_b.qiita"
        }
      ]
      tags        = null
    }
  ])
}

resource "aws_ecs_task_definition" "service_b" {
  family                   = "${local.app_name}_service_b"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name         = "service_b"
      image        = local.images.service_b
      cpu          = 256
      memory       = 512
      essential    = true
      network_mode = "awsvpc"
      portMappings = [
        {
          name          = "service_b"
          containerPort = 8081
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        {
          name  = "SERVICE_A_URL"
          value = "http://service_a.qiita"
        }
      ]
    }
  ])
}

# # ECS Service
# # https://registry.terraform.io/providers/hashicorp/aws/2.43.0/docs/resources/ecs_service
resource "aws_ecs_service" "service_a" {
  name            = "service_a"
  cluster         = aws_ecs_cluster.main.id
  desired_count   = 1
  task_definition = aws_ecs_task_definition.service_a.arn
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 100
  }
  network_configuration {
    subnets = [
      aws_subnet.public_1a.id
    ]
    security_groups = [
      aws_security_group.service_a.id,
    ]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled = true
    service {
      client_alias {
        port = 3000
      }
      port_name = "service_a"
    }

    namespace = aws_service_discovery_http_namespace.qiita.arn
  }
}

resource "aws_ecs_service" "service_b" {
  name                              = "service_b"
  cluster                           = aws_ecs_cluster.main.id
  desired_count                     = 1
  task_definition                   = aws_ecs_task_definition.service_b.arn
  health_check_grace_period_seconds = 0
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 100
  }
  network_configuration {
    subnets = [
      aws_subnet.public_1a.id
    ]
    security_groups = [
      aws_security_group.service_b.id,
    ]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled = true
    service {
      client_alias {
        port = 3000
      }
      port_name = "service_b"
    }

    namespace = aws_service_discovery_http_namespace.qiita.arn
  }
}
