provider "aws" {
  region  = "ap-northeast-1"
  profile = var.aws_profile_name
  alias   = "jp"
}

provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile_name
  alias   = "us"
}

terraform {
  backend "local" {
    path = ".cache/terraform.tfstate"
  }
}


variable "aws_profile_name" {
  description = "AWSのプロファイル名"
  type        = string
}