provider "aws" {
  alias  = "dev"
  region = "us-west-2"
  profile = "tf-dev/AWSAdministratorAccess"  # This is the base profile or root account that has permission to assume roles
}

provider "aws" {
  alias  = "work1dev"
  region = "us-west-2"
}

provider "aws" {
  alias  = "work2dev"
  region = "us-west-2"
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}