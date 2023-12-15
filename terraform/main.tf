terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.5.0"
    }
  }
}

variable "administrator" {}
variable "user_id" {}
variable "access_key" {}
variable "secret_key" {}

locals {
  app_name = "qiita"

  allowed_ips = ["0.0.0.0/0"]

  # dockerイメージ
  images = {
    service_a : "${var.user_id}.dkr.ecr.ap-northeast-1.amazonaws.com/service_a:latest"
    service_b : "${var.user_id}.dkr.ecr.ap-northeast-1.amazonaws.com/service_b:latest"
  }
}

provider "aws" {
  region     = "ap-northeast-1"
  access_key = var.access_key
  secret_key = var.secret_key
  default_tags {
    tags = {
      application   = local.app_name
      Name          = local.app_name
      administrator = var.administrator
    }
  }
}

resource "aws_ecr_repository" "service_a" {
  name                 = "service_a"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "service_b" {
  name                 = "service_b"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
