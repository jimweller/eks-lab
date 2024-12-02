terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }


  backend "s3" {
    bucket = "tfstate-ee03fdccbeb4bf4177b97d1c3289b2ab06089789"
    key    = "eks-lab-cluster.tfstate"
    region = "us-west-2"
  }

  required_version = "~> 1.0"
}
