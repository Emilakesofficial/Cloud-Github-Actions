# LOCAL VALUES
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    DeployedVia = "Github-Actions"
    Owner       = "adekunle"
  }
}
# Demo d3 bucket

resource "aws_s3_bucket" "demo_bucket" {
  bucket = "${var.demo_bucket_name}-${var.environment}"

  tags = merge(local.common_tags, {
    Name = "${var.demo_bucket_name}-${var.environment}"
  })
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "demo_bucket_versioning" {
  bucket = aws_s3_bucket.demo_bucket.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "demo_bucket_encryption" {
  bucket = aws_s3_bucket.demo_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block All Public Access
resource "aws_s3_bucket_public_access_block" "demo_bucket_public_access_block" {
  bucket = aws_s3_bucket.demo_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}