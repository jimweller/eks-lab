############################################
# EKS Cluster
############################################

module "eks" {

  # lock down api to my IP
  cluster_endpoint_public_access_cidrs = ["97.113.133.254/32"]

  providers = {
    aws = aws.dev
  }

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "dev-eks-cluster"
  cluster_version = "1.31"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access = true

  enable_irsa = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

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
    }
    tags = {
      "k8s.io/cluster-autoscaler/enabled"         = "true"
      "k8s.io/cluster-autoscaler/dev-eks-cluster" = "true"
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

  source          = "terraform-aws-modules/vpc/aws"
  name            = "dev-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
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

