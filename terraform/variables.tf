# AWS REGION
variable "aws_region" {
  description = "This AWS region where resources will be deployed"
  type        = string
  default     = "us-east-1"
}

# ENVIRONMENT
variable "environment" {
  description = "The deployment environment (dev, staging, production)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

# PROJECT NAME
variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "github-actions-demo"
}

# S3 DEMO BUCKET CONFIGURATION
variable "demo_bucket_name" {
  description = "The name of the demo s3 bucket Terraform will manage"
  type        = string
  default     = "terraform-managed-demo-adekunle"
}

variable "enable_versioning" {
  description = "Whether to enable versioning on the demo s3 bucket"
  type        = bool
  default     = true
}