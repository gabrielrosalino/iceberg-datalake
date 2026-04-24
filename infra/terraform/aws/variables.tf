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

variable "processing_image" {
  description = "DockerHub image pulled by ECS/Fargate to execute the processing job."
  type        = string
  default     = "gabrielrosalino/iceberg-datalake-processing:latest"
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 2048
}

variable "vpc_id" {
  description = "VPC id where the ECS task will run."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets used by the ECS task."
  type        = list(string)
}

variable "allowed_egress_cidr_blocks" {
  description = "CIDR blocks allowed for outbound traffic."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
