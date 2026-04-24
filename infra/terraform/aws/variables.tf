variable "aws_region" {
  description = "AWS region used by the datalake resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used to prefix resources."
  type        = string
  default     = "iceberg-datalake"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}
