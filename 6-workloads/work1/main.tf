provider "aws" {
  region = "us-west-2"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }


  backend "s3" {
    bucket = "tfstate-9e33116dc774f942945a820690449e9d"
    key    = "eks-lab-work.tfstate"
    region = "us-west-2"
  }

  required_version = "~> 1.0"
}



data "aws_caller_identity" "current" {}

module "ssm_parameter" {
  source      = "../tfmods/ssm_param"
  worker_name = "work1"
}

module "superuser_role" {
  source = "../tfmods/superuser_role"
}
