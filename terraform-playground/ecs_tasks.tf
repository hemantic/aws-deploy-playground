resource "aws_cloudwatch_log_group" "web" {
  name              = local.aws_ecs_service_web_name
  retention_in_days = 5
}

resource "aws_cloudwatch_log_group" "celery" {
  name              = local.aws_ecs_service_celery_name
  retention_in_days = 5
}

resource "aws_cloudwatch_log_group" "flower" {
  name              = local.aws_ecs_service_flower_name
  retention_in_days = 5
}

resource "aws_ecs_task_definition" "web" {
  container_definitions = data.template_file.container_image_web.rendered
  family                = local.aws_ecs_task_web_name
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  network_mode          = "bridge"
}

resource "aws_ecs_task_definition" "celery" {
  container_definitions = data.template_file.container_image_celery.rendered
  family                = local.aws_ecs_task_celery_name
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  network_mode          = "bridge"
}

resource "aws_ecs_task_definition" "flower" {
  container_definitions = data.template_file.container_image_flower.rendered
  family                = local.aws_ecs_task_flower_name
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  network_mode          = "bridge"
}

data "template_file" "container_image_web" {
  template   = file("aws-ecs-task-definitions/playground.json")
  depends_on = [aws_elasticache_replication_group.default]
  vars = {
    service_name      = local.aws_ecs_service_web_name
    image_name        = aws_ecr_repository.playground.repository_url
    aws_region        = var.aws_region
    log_stream_prefix = "web_"
    command           = "uwsgi --http :80 --module srv.web:app --workers 1 --threads 1"

    sample_env_var = local.sample_env_var_arn
    redis_url      = "redis://${aws_elasticache_replication_group.default.primary_endpoint_address}:${aws_elasticache_replication_group.default.port}"
  }
}

data "template_file" "container_image_celery" {
  template   = file("aws-ecs-task-definitions/playground.json")
  depends_on = [aws_elasticache_replication_group.default]
  vars = {
    service_name      = local.aws_ecs_service_celery_name
    image_name        = aws_ecr_repository.playground.repository_url
    aws_region        = var.aws_region
    log_stream_prefix = "celery_"
    command           = "celery -A srv.tasks:celery worker"

    sample_env_var = local.sample_env_var_arn
    redis_url      = "redis://${aws_elasticache_replication_group.default.primary_endpoint_address}:${aws_elasticache_replication_group.default.port}"
  }
}

data "template_file" "container_image_flower" {
  template   = file("aws-ecs-task-definitions/playground.json")
  depends_on = [aws_elasticache_replication_group.default]
  vars = {
    service_name      = local.aws_ecs_service_flower_name
    image_name        = aws_ecr_repository.playground.repository_url
    aws_region        = var.aws_region
    log_stream_prefix = "flower_"
    command           = "celery -A srv.tasks:celery flower --port=80"

    sample_env_var = local.sample_env_var_arn
    redis_url      = "redis://${aws_elasticache_replication_group.default.primary_endpoint_address}:${aws_elasticache_replication_group.default.port}"
  }
}
