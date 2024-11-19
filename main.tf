############################################
# EKS Cluster
############################################

module "eks" {
  source = "terraform-aws-modules/eks/aws"

  providers = {
    aws = aws.dev
  }



  # lock down api to my IP
  cluster_endpoint_public_access_cidrs = ["97.113.133.254/32"]

  version = "~> 20.0"

  cluster_name    = "dev-eks-cluster"
  cluster_version = "1.31"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  enable_irsa = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id = module.vpc.vpc_id

  control_plane_subnet_ids = slice(module.vpc.private_subnets, 0, 2)
  subnet_ids               = slice(module.vpc.private_subnets, 2, 4)


  # EKS Managed Node Group(s)
  # 2 CPU, 4GB
  eks_managed_node_group_defaults = {
    instance_types = ["t3a.medium", "t3.medium", "t2.medium"]
  }

  eks_managed_node_groups = {
    dev-eks-nodegroup = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3a.medium"]

      min_size     = 1
      max_size     = 3
      desired_size = 1
      tags = {
        "k8s.io/cluster-autoscaler/enabled"         = "true"
        "k8s.io/cluster-autoscaler/dev-eks-cluster" = "true"
      }
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]


}

module "vpc" {
  providers = {
    aws = aws.dev
  }

  source = "terraform-aws-modules/vpc/aws"
  name   = "dev-vpc"
  cidr   = "10.0.0.0/16"
  azs    = ["us-west-2a", "us-west-2b"]

  # 2 az subnets per account
  # control plane AB, cluster AB, work1 AB, work2 AB
  private_subnets = ["10.0.8.0/24", "10.0.88.0/24", "10.0.9.0/24", "10.0.99.0/24", "10.0.1.0/24", "10.0.10.0/24", "10.0.2.0/24", "10.0.20.0/24"]
  private_subnet_names = ["control-plane-a", "control-plane-b", "cluster-a", "cluster-b", "work1-a", "work1-b", "work2-a", "work2-b"]

  # 2 az subnets per account
  # cluster AB, work1 AB, work2 AB
  public_subnets = ["10.0.109.0/24", "10.0.199.0/24", "10.0.101.0/24", "10.0.110.0/24", "10.0.102.0/24", "10.0.120.0/24"]

  # One NAT Gateway per availability zone
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  tags = {
    Environment = "dev"
  }
}


############################################
# autoscaler pod identity
############################################

resource "aws_iam_role" "cluster_autoscaler_role" {
  provider = aws.dev

  name = "ClusterAutoscalerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}




resource "aws_iam_policy" "cluster_autoscaler_policy" {
  provider = aws.dev

  name        = "ClusterAutoscalerPolicy"
  description = "Policy for EKS Cluster Autoscaler"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ],
        "Resource" : ["*"]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        "Resource" : ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_policy_attachment" {
  provider = aws.dev

  role       = aws_iam_role.cluster_autoscaler_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  provider = aws.dev

  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler_role.arn
}


resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = aws_eks_pod_identity_association.cluster_autoscaler.service_account
    namespace = "kube-system"
  }
}



############################################
# RAM VPC Share
############################################

# needs to be done as org account, not tf account, did it on the console
# resource "aws_ram_sharing_with_organization" "enable_ram_in_org" {}


# work 1 subnets
resource "aws_ram_resource_share" "work1_vpc_ram_share" {
  provider                  = aws.dev
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
  provider                  = aws.dev
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
