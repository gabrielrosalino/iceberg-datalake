locals {
  name_prefix              = "${var.project_name}-${var.environment}"
  artifacts_bucket_name    = "${local.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
  s3_table_bucket_name     = "${local.name_prefix}-tables"
  ecs_cluster_name         = "${local.name_prefix}-cluster"
  ecs_task_family          = "${local.name_prefix}-processing"
  processing_container     = "processing"
  athena_results_location  = "s3://${aws_s3_bucket.artifacts.bucket}/athena-results/"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = local.artifacts_bucket_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "raw-data-dbt-artifacts-athena-results"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3tables_table_bucket" "lakehouse" {
  name = local.s3_table_bucket_name
}

resource "aws_s3tables_namespace" "bronze" {
  namespace        = "bronze"
  table_bucket_arn = aws_s3tables_table_bucket.lakehouse.arn
}

resource "aws_s3tables_namespace" "silver" {
  namespace        = "silver"
  table_bucket_arn = aws_s3tables_table_bucket.lakehouse.arn
}

resource "aws_s3tables_namespace" "gold" {
  namespace        = "gold"
  table_bucket_arn = aws_s3tables_table_bucket.lakehouse.arn
}

resource "aws_cloudwatch_log_group" "processing" {
  name              = "/ecs/${local.ecs_task_family}"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "lakehouse" {
  name = local.ecs_cluster_name
}

resource "aws_security_group" "ecs_processing" {
  name        = "${local.name_prefix}-ecs-processing"
  description = "Security group for ECS processing tasks"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed_egress_cidr_blocks
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name_prefix}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_processing_task" {
  name               = "${local.name_prefix}-ecs-processing-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_processing_task" {
  statement {
    sid = "ArtifactsBucketAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }

  statement {
    sid = "S3TablesAccess"
    actions = [
      "s3tables:GetTableBucket",
      "s3tables:ListTableBuckets",
      "s3tables:CreateNamespace",
      "s3tables:GetNamespace",
      "s3tables:ListNamespaces",
      "s3tables:CreateTable",
      "s3tables:GetTable",
      "s3tables:ListTables",
      "s3tables:UpdateTableMetadataLocation",
      "s3tables:GetTableMetadataLocation",
      "s3tables:DeleteTable"
    ]
    resources = [
      aws_s3tables_table_bucket.lakehouse.arn,
      "${aws_s3tables_table_bucket.lakehouse.arn}/*"
    ]
  }

  statement {
    sid = "AthenaAccess"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:StopQueryExecution"
    ]
    resources = ["*"]
  }

  statement {
    sid = "GlueReadAccess"
    actions = [
      "glue:GetCatalog",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_processing_task" {
  name   = "${local.name_prefix}-ecs-processing-task"
  policy = data.aws_iam_policy_document.ecs_processing_task.json
}

resource "aws_iam_role_policy_attachment" "ecs_processing_task" {
  role       = aws_iam_role.ecs_processing_task.name
  policy_arn = aws_iam_policy.ecs_processing_task.arn
}

resource "aws_ecs_task_definition" "processing" {
  family                   = local.ecs_task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_processing_task.arn

  container_definitions = jsonencode([
    {
      name      = local.processing_container
      image     = var.processing_image
      essential = true
      command   = ["python", "-m", "app.pipeline"]

      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "S3_TABLE_BUCKET_NAME", value = aws_s3tables_table_bucket.lakehouse.name },
        { name = "S3_TABLE_WAREHOUSE", value = "s3tables://${aws_s3tables_table_bucket.lakehouse.name}" },
        { name = "S3_TABLE_NAMESPACE_BRONZE", value = aws_s3tables_namespace.bronze.namespace },
        { name = "S3_TABLE_NAMESPACE_SILVER", value = aws_s3tables_namespace.silver.namespace },
        { name = "S3_TABLE_NAMESPACE_GOLD", value = aws_s3tables_namespace.gold.namespace },
        { name = "S3_ARTIFACTS_BUCKET", value = aws_s3_bucket.artifacts.bucket },
        { name = "RAW_DATA_PREFIX", value = "raw/open_meteo" },
        { name = "ATHENA_RESULTS_PREFIX", value = "athena-results" },
        { name = "DUCKDB_DATABASE", value = "/app/data/duckdb/lakehouse.duckdb" },
        { name = "DBT_PROJECT_DIR", value = "/app/dbt" },
        { name = "DBT_PROFILES_DIR", value = "/app/dbt" },
        { name = "OPEN_METEO_DAYS_BACK", value = "30" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.processing.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_athena_workgroup" "analytics" {
  name = "${local.name_prefix}-analytics"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = local.athena_results_location
    }
  }
}
