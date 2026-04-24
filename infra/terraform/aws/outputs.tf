output "lakehouse_bucket" {
  description = "S3 bucket used by the datalake."
  value       = aws_s3_bucket.lakehouse.bucket
}

output "bronze_database" {
  value = aws_glue_catalog_database.bronze.name
}

output "silver_database" {
  value = aws_glue_catalog_database.silver.name
}

output "gold_database" {
  value = aws_glue_catalog_database.gold.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.analytics.name
}
