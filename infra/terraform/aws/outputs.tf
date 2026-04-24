output "s3_table_bucket_name" {
  description = "S3 Tables bucket used for Iceberg tables."
  value       = aws_s3tables_table_bucket.lakehouse.name
}

output "s3_table_bucket_arn" {
  description = "S3 Tables bucket ARN."
  value       = aws_s3tables_table_bucket.lakehouse.arn
}

output "artifacts_bucket" {
  description = "S3 bucket used for raw API payloads, dbt artifacts and Athena results."
  value       = aws_s3_bucket.artifacts.bucket
}

output "ecs_cluster_name" {
  description = "ECS cluster used by Airflow EcsRunTaskOperator."
  value       = aws_ecs_cluster.lakehouse.name
}

output "ecs_task_definition" {
  description = "ECS task definition family used by Airflow."
  value       = aws_ecs_task_definition.processing.family
}

output "ecs_container_name" {
  description = "Container name overridden by Airflow."
  value       = local.processing_container
}

output "ecs_security_group_id" {
  description = "Security group used by the ECS processing task."
  value       = aws_security_group.ecs_processing.id
}

output "athena_workgroup" {
  value = aws_athena_workgroup.analytics.name
}
