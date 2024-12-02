provider "aws" {
  region = "us-west-2"
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.cluster.outputs.eks_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.eks_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
}