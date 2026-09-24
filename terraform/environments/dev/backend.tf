terraform {
  backend "s3" {
    bucket = "tf-state-7afc2a05"
    key    = "aws-ai-bankapp/dev/terraform.tfstate"
    region = "us-east-1"

    # Native S3 state locking
    use_lockfile = true

    encrypt = true
  }

}

