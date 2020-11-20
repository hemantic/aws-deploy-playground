variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_account_id" {}
variable "aws_region" {}

variable "app_name" {}


terraform {
  required_version = ">= 0.13"

  backend "s3" {
    bucket  = "hemantic-playground-terraform-state"
    key     = "global/s3/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
  version    = "~> 2.70"
}

locals {
  aws_ecr_repository_name = var.app_name
  aws_ecs_cluster_name    = var.app_name
  aws_ecs_stack_name      = var.app_name

  aws_iam_instance_role       = "${var.app_name}InstanceRole"
  aws_iam_task_execution_role = "${var.app_name}TaskExecutionRole"
  aws_iam_policy_secrets_name = "${var.app_name}SecretsManager"
  aws_iam_instance_profile    = "${var.app_name}InstanceProfile"

  aws_redis_engine_version       = "6.x"
  aws_redis_sg_name              = "${var.app_name}RedisSG"
  aws_redis_parameter_group_name = "${var.app_name}.redis${local.aws_redis_engine_version}"
  aws_redis_replication_group    = "${var.app_name}RedisRG"

  aws_ecs_task_web_name    = "${var.app_name}Task-web"
  aws_ecs_service_web_name = "${var.app_name}Service-web"

  aws_ecs_task_celery_name    = "${var.app_name}Task-celery"
  aws_ecs_service_celery_name = "${var.app_name}Service-celery"

  aws_ecs_task_flower_name    = "${var.app_name}Task-flower"
  aws_ecs_service_flower_name = "${var.app_name}Service-flower"

  availability_zones  = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
  vpc_cidr            = "10.0.0.0/16"
  private_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets      = ["10.0.101.0/24", "10.0.102.0/24"]
  elasticache_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

  sample_env_var_arn = "arn:aws:secretsmanager:eu-north-1:759973589405:secret:/playground/prod/SAMPLE_ENV_VAR-6UjTjO"
}

resource "aws_ecs_cluster" "cluster" {
  name = local.aws_ecs_cluster_name
}

resource "aws_ecs_service" "web" {
  name = local.aws_ecs_service_web_name

  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
}

resource "aws_ecs_service" "celery" {
  name = local.aws_ecs_service_celery_name

  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.celery.arn
  desired_count   = 1
}

resource "aws_ecs_service" "flower" {
  name = local.aws_ecs_service_flower_name

  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.flower.arn
  desired_count   = 1
}
