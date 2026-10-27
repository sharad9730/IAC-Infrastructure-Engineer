terraform {
  backend "s3" {
    bucket         = "my-tf-state-bucket"
    key            = "devops-assign/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
