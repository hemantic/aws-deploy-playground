variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_account_id" {}
variable "aws_region" {}
variable "aws_ecr_repository_name" {}
variable "aws_ecs_cluster_name" {}
variable "aws_ecs_stack_name" {}

variable "aws_ecs_task_web_name" {}
variable "aws_ecs_service_web_name" {}

variable "aws_ecs_task_celery_name" {}
variable "aws_ecs_service_celery_name" {}

variable "aws_ecs_task_flower_name" {}
variable "aws_ecs_service_flower_name" {}

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
  availability_zones  = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
  vpc_cidr            = "10.0.0.0/16"
  private_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets      = ["10.0.101.0/24", "10.0.102.0/24"]
  elasticache_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

  sample_env_var_arn = "arn:aws:secretsmanager:eu-north-1:759973589405:secret:/playground/prod/SAMPLE_ENV_VAR-6UjTjO"
}

resource "aws_ecr_repository" "playground" {
  name = var.aws_ecr_repository_name
}

resource "aws_ecr_lifecycle_policy" "max_images" {
  repository = aws_ecr_repository.playground.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keeping only 3 youngest images; expires the old ones",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 3
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_ecs_cluster" "cluster" {
  name = var.aws_ecs_cluster_name
}

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_role" {
  name               = "ecs-playground-role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-playground-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}

resource "aws_iam_role_policy" "password_policy_secretsmanager" {
  name = "password-policy-secretsmanager"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Effect": "Allow",
      "Resource": [
        "${local.sample_env_var_arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_iam_policy_attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "instance-profile"
  path = "/"
  role = aws_iam_role.ecs_role.name
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.aws_ecs_stack_name
  cidr = local.vpc_cidr

  azs                 = local.availability_zones
  private_subnets     = local.private_subnets
  public_subnets      = local.public_subnets
  elasticache_subnets = local.elasticache_subnets

  enable_nat_gateway = true
}

resource "aws_cloudformation_stack" "stack" {
  name = var.aws_ecs_stack_name

  template_body = file("aws-templates/aws-ecs-stack.yml")
  depends_on    = [aws_iam_instance_profile.instance_profile, module.vpc]

  parameters = {
    VpcId = module.vpc.vpc_id

    AsgMaxSize              = 3
    AutoAssignPublicIp      = "INHERIT"
    ConfigureDataVolume     = false
    ConfigureRootVolume     = true
    DeviceName              = "/dev/xvdcz"
    EbsVolumeSize           = 22
    EbsVolumeType           = "gp2"
    EcsAmiId                = "ami-03fc956d7468aa8a1"
    EcsClusterName          = var.aws_ecs_cluster_name
    EcsInstanceType         = "t3.micro"
    IamRoleInstanceProfile  = aws_iam_instance_profile.instance_profile.arn
    IsWindows               = false
    KeyName                 = "wondersell-ecs-default"
    RootDeviceName          = "/dev/xvda"
    RootEbsVolumeSize       = 30
    SecurityIngressCidrIp   = "0.0.0.0/0"
    SecurityIngressFromPort = 80
    SecurityIngressToPort   = 80
    SpotAllocationStrategy  = "diversified"
    SubnetIds               = join(",", module.vpc.public_subnets)
    UseSpot                 = false
    UserData                = "#!/bin/bash\necho ECS_CLUSTER=${var.aws_ecs_cluster_name} >> /etc/ecs/ecs.config;echo ECS_BACKEND_HOST= >> /etc/ecs/ecs.config;"
  }
}

resource "aws_ecs_task_definition" "web" {
  container_definitions = data.template_file.container_image_web.rendered
  family                = var.aws_ecs_task_web_name
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_task_definition" "celery" {
  container_definitions = data.template_file.container_image_celery.rendered
  family                = var.aws_ecs_task_celery_name
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_task_definition" "flower" {
  container_definitions = data.template_file.container_image_flower.rendered
  family                = var.aws_ecs_task_flower_name
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "web" {
  name = var.aws_ecs_service_web_name

  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
}

resource "aws_ecs_service" "celery" {
  name = var.aws_ecs_service_celery_name

  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.celery.arn
  desired_count   = 1
}

resource "aws_ecs_service" "flower" {
  name = var.aws_ecs_service_flower_name

  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.flower.arn
  desired_count   = 1
}

data "template_file" "container_image_web" {
  template = file("aws-ecs-task-definitions/playground-web.json")
  vars = {
    service_name = var.aws_ecs_service_web_name
    image_name   = aws_ecr_repository.playground.repository_url
    aws_region   = var.aws_region
    command      = "uwsgi --http :80 --module srv.web:app --workers 1 --threads 1"

    sample_env_var = local.sample_env_var_arn
    redis_url      = module.redis.endpoint
  }
}

data "template_file" "container_image_celery" {
  template = file("aws-ecs-task-definitions/playground-web.json")
  vars = {
    service_name = var.aws_ecs_service_web_name
    image_name   = aws_ecr_repository.playground.repository_url
    aws_region   = var.aws_region
    command      = "celery -A srv.tasks:celery worker"

    sample_env_var = local.sample_env_var_arn
    redis_url      = module.redis.endpoint
  }
}

data "template_file" "container_image_flower" {
  template = file("aws-ecs-task-definitions/playground-web.json")
  vars = {
    service_name = var.aws_ecs_service_web_name
    image_name   = aws_ecr_repository.playground.repository_url
    aws_region   = var.aws_region
    command      = "celery -A srv.tasks:celery flower --port=80"

    sample_env_var = local.sample_env_var_arn
    redis_url      = module.redis.endpoint
  }
}

module "redis" {
  source  = "cloudposse/elasticache-redis/aws"
  version = "0.25.0"

  depends_on = [module.vpc]

  availability_zones               = module.vpc.azs
  vpc_id                           = module.vpc.vpc_id
  allowed_security_groups          = [module.vpc.default_security_group_id]
  subnets                          = module.vpc.elasticache_subnets
  elasticache_subnet_group_name    = module.vpc.elasticache_subnet_group_name
  environment                      = var.aws_region
  cluster_size                     = 1
  instance_type                    = "cache.t3.small"
  apply_immediately                = true
  automatic_failover_enabled       = false
  engine_version                   = "6.x"
  family                           = "redis6.x"
  at_rest_encryption_enabled       = false
  transit_encryption_enabled       = false
  cloudwatch_metric_alarms_enabled = false

  parameter = [
    {
      name  = "notify-keyspace-events"
      value = "lK"
    }
  ]
}
