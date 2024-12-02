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
    bucket = "tfstate-ca3fef7a46bb5d70b159c68af83bb6f8"
    key    = "eks-lab-work.tfstate"
    region = "us-west-2"
  }

  required_version = "~> 1.0"
}



data "aws_caller_identity" "current" {}

module "ssm_parameter" {
  source      = "../tfmods/ssm_param"
  worker_name = "work2"
}

module "superuser_role" {
  source = "../tfmods/superuser_role"
}
