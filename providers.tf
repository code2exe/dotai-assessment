# Configure the AWS Provider
provider "aws" {
}

provider "github" {
    token = var.pa_token
}