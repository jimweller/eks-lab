locals {
  private_subnet_config = {
    "10.0.0.0/24"  = { name = "controlplane-a", role = "controlplane" }
    "10.0.1.0/24" = { name = "controlplane-b", role = "controlplane" }
    "10.0.10.0/24"  = { name = "workloads-a", role = "workloads" }
    "10.0.11.0/24" = { name = "workloads-b", role = "workloads" }
    "10.0.101.0/24"  = { name = "ram1-a", role = "ram1" }
    "10.0.102.0/24" = { name = "ram1-b", role = "ram1" }
    "10.0.201.0/24"  = { name = "ram2-a", role = "ram2" }
    "10.0.202.0/24" = { name = "ram2-b", role = "ram2" }
  }


  ordered_private_subnet_keys = [
    "10.0.0.0/24",
    "10.0.1.0/24",
    "10.0.10.0/24",
    "10.0.11.0/24",
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.201.0/24",
    "10.0.202.0/24"
  ]


  public_subnet_config = {
    "10.0.20.0/24"  = { name = "public-a", role = "public" }
    "10.0.21.0/24" = { name = "public-b", role = "public" }
  }


  ordered_public_subnet_keys = [
    "10.0.20.0/24",
    "10.0.21.0/24"
  ]

}


############################################
# EKS Cluster
############################################

module "eks" {
  source = "terraform-aws-modules/eks/aws"

  # lock down api to my IP
  cluster_endpoint_public_access_cidrs = ["63.228.98.56/32"]

  version = "~> 20.0"

  cluster_name    = "dev-eks-cluster"
  cluster_version = "1.31"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  enable_irsa = true

  cluster_addons = {
    coredns = {
      addon_version = "v1.11.3-eksbuild.1"
    }
    eks-pod-identity-agent = {
      addon_version = "v1.3.4-eksbuild.1"
    }
    kube-proxy = {
      addon_version = "v1.31.2-eksbuild.3"
    }
    vpc-cni = {
      addon_version = "v1.19.0-eksbuild.1"
    }
  }

  vpc_id = module.vpc.vpc_id

  control_plane_subnet_ids = slice(module.vpc.private_subnets, 0, 2)
  subnet_ids               = slice(module.vpc.private_subnets, 2, 4)


  # EKS Managed Node Group(s)
  # 2 CPU, 4GB
  # eks_managed_node_group_defaults = {
  #   instance_types = ["t3a.medium", "t3.medium", "t2.medium"]
  # }

  eks_managed_node_groups = {

    controlplane = {
      lifecycle = {
        create_before_destroy = true
      }
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = ["t4g.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 1
      subnet_ids     = slice(module.vpc.private_subnets, 0, 2)
      tags = {
        "k8s.io/cluster-autoscaler/enabled"         = "true"
        "k8s.io/cluster-autoscaler/dev-eks-cluster" = "true"
      }
      labels = {
        "role" = "controlplane"
      }
      # taints = {
      #   control-plane = {
      #     key    = "dedicated"
      #     value  = "controlplane"
      #     effect = "NO_SCHEDULE"
      #   }
      # }
    }

    workloads = {
      lifecycle = {
        create_before_destroy = true
      }
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = ["t4g.medium"]
      capacity_type  = "SPOT"

      min_size     = 0
      max_size     = 5
      desired_size = 0
      subnet_ids     = slice(module.vpc.private_subnets, 2, 4)
      tags = {
        "k8s.io/cluster-autoscaler/enabled"         = "true"
        "k8s.io/cluster-autoscaler/dev-eks-cluster" = "true"
      }
      labels = {
        "role" = "workloads"
      }
      # taints = {
      #   control-plane = {
      #     key    = "dedicated"
      #     value  = "workloads"
      #     effect = "NO_SCHEDULE"
      #   }
      # }
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = 1


}

module "vpc" {

  source = "terraform-aws-modules/vpc/aws"
  name   = "dev-vpc"
  cidr   = "10.0.0.0/16"
  azs    = ["us-west-2a", "us-west-2b"]

  # 2 az subnets per account
  # control plane AB, cluster AB, work1 AB, work2 AB
  # private_subnets      = ["10.0.8.0/24", "10.0.88.0/24", "10.0.9.0/24", "10.0.99.0/24", "10.0.1.0/24", "10.0.10.0/24", "10.0.2.0/24", "10.0.20.0/24"]
  # private_subnet_names = ["controlplane-a", "controlplane-b", "cluster-a", "cluster-b", "work1-a", "work1-b", "work2-a", "work2-b"]

  # control plane AB, cluster AB, work AB
  private_subnets = local.ordered_private_subnet_keys
  # private_subnet_tags = local.private_subnet_config

  # 2 az subnets per account
  # cluster AB, work1 AB, work2 AB
  public_subnets = local.ordered_public_subnet_keys

  # One NAT Gateway
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Environment = "dev"
  }
}





############################################
# RAM VPC Share
############################################

# needs to be done as org account, not tf account, unless you want to give it org perms, did it on the console
# resource "aws_ram_sharing_with_organization" "enable_ram_in_org" {}


# work 1 subnets
resource "aws_ram_resource_share" "work1_vpc_ram_share" {
  name                      = "work1-vpc-ram-share"
  allow_external_principals = false
}


resource "aws_ram_principal_association" "work1_ram_association" {
  principal          = "296062590485"
  resource_share_arn = aws_ram_resource_share.work1_vpc_ram_share.arn
}

locals {
  work1_subnet_arns = slice(module.vpc.private_subnet_arns, 4, 6)
}

resource "aws_ram_resource_association" "work1_subnet_share" {
  for_each           = { for idx, arn in local.work1_subnet_arns : idx => arn }
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.work1_vpc_ram_share.arn
}


# work 2 subnets
resource "aws_ram_resource_share" "work2_vpc_ram_share" {
  name                      = "work2-vpc-ram-share"
  allow_external_principals = false
}

resource "aws_ram_principal_association" "work2_ram_association" {
  principal          = "195275675931"
  resource_share_arn = aws_ram_resource_share.work2_vpc_ram_share.arn
}

locals {
  work2_subnet_arns = slice(module.vpc.private_subnet_arns, 6, 8)
}

resource "aws_ram_resource_association" "work2_subnet_share" {
  for_each           = { for idx, arn in local.work2_subnet_arns : idx => arn }
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.work2_vpc_ram_share.arn
}