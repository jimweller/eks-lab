data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_default_tags" "current" {}
data "aws_availability_zones" "current" {}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.cluster.outputs.eks_name
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.cluster.outputs.eks_name
}

data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket = "tfstate-ee03fdccbeb4bf4177b97d1c3289b2ab06089789"
    key    = "eks-lab-cluster.tfstate"
    region = "us-west-2"
  }
}

