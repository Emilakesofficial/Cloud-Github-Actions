terraform {
  backend "s3" {
    bucket       = "tf-state-github-actions-demo-adekunle"
    key          = "terraform/state/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}