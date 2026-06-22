# OUTPUT VALUES

# Demo Bucket Outputs
output "demo_bucket_name" {
  description = "The name of the demo S3 bucket created by Terraform"
  value       = aws_s3_bucket.demo_bucket.bucket
}

output "demo_bucket_arn" {
  description = "The ARN of the demo S3 bucket"
  value       = aws_s3_bucket.demo_bucket.arn
}

output "demo_bucket_region" {
  description = "The AWS region where the demo bucket was created"
  value       = aws_s3_bucket.demo_bucket.region
}

output "demo_bucket_versioning_status" {
  description = "The versioning status of the demo bucket"
  value       = aws_s3_bucket_versioning.demo_bucket_versioning.versioning_configuration[0].status
}

# Environment Info Outputs
output "environment" {
  description = "The environment this infrastructure was deployed to"
  value       = var.environment
}

output "project_name" {
  description = "The project name"
  value       = var.project_name
}