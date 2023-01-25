terraform {
  backend "s3" {
    bucket = "dotai-state-bucket"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }
}