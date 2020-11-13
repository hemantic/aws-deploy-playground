provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
  version    = "~> 2.70"
}

locals {
  aws_ecr_repository_name = "ecr-playground-repo"
  aws_ecs_cluster_name    = "ecs-playground-cluster"
  aws_ecs_stack_name      = "ecs-playground-stack"

  aws_ecs_task_web_name    = "ecs-playground-task-web"
  aws_ecs_service_web_name = "ecs-playground-service-web"
}

resource "aws_ecs_cluster" "cluster" {
  name = local.aws_ecs_cluster_name
}

resource "aws_iam_role" "ecs_role" {
  name               = "ecs-playground-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_iam_policy_attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "instance-profile"
  path = "/"
  role = aws_iam_role.ecs_role.name
}

resource "aws_cloudformation_stack" "stack" {
  name = local.aws_ecs_stack_name

  template_body = file("aws-templates/aws-ecs-stack.yml")
  depends_on    = [aws_iam_instance_profile.instance_profile]

  parameters = {
    AsgMaxSize              = 1
    AutoAssignPublicIp      = "INHERIT"
    ConfigureDataVolume     = false
    ConfigureRootVolume     = true
    DeviceName              = "/dev/xvdcz"
    EbsVolumeSize           = 22
    EbsVolumeType           = "gp2"
    EcsAmiId                = "ami-03fc956d7468aa8a1"
    EcsClusterName          = local.aws_ecs_cluster_name
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
    SubnetCidr1             = "10.0.0.0/24"
    SubnetCidr2             = "10.0.1.0/24"
    UseSpot                 = false
    UserData                = "#!/bin/bash\necho ECS_CLUSTER=${local.aws_ecs_cluster_name} >> /etc/ecs/ecs.config;echo ECS_BACKEND_HOST= >> /etc/ecs/ecs.config;"
    VpcAvailabilityZones    = "eu-north-1a,eu-north-1b,eu-north-1c"
    VpcCidr                 = "10.0.0.0/16"
  }
}

resource "aws_ecs_task_definition" "web" {
  container_definitions = file("aws-ecs-task-definitions/playground-web.json")
  family                = local.aws_ecs_task_web_name
}

resource "aws_ecs_service" "web" {
  name = local.aws_ecs_service_web_name

  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
}