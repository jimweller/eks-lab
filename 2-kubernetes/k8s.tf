resource "kubernetes_namespace" "upbound" {
  metadata {
    name = "upbound-system"
  }
}

resource "kubernetes_namespace" "workloads" {
  metadata {
    name = "workloads"
  }
}

############################################
# superuser pod identity
############################################

resource "aws_iam_role" "superuser_pod_role" {

  name = "superuser-pod"

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

resource "aws_iam_role" "superuser_irsa_role" {
  name = "superuser-irsa"


  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = data.terraform_remote_state.cluster.outputs.oidc_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(data.terraform_remote_state.cluster.outputs.oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com",
            "${replace(data.terraform_remote_state.cluster.outputs.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:workloads:superuser-irsa"
          }
        }
      }
    ]
  })
}


resource "aws_iam_policy" "superuser_policy" {

  name        = "superuser-policy"
  description = "Policy for EKS Cluster Autoscaler"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "sts:AssumeRole",
          "sts:TagSession"
        ],
        Resource : "arn:aws:iam::*:role/superuser"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "superuser_policy_attachment" {
  role       = aws_iam_role.superuser_pod_role.name
  policy_arn = aws_iam_policy.superuser_policy.arn
}


resource "aws_iam_role_policy_attachment" "superuser_irsa_policy_attachment" {
  role       = aws_iam_role.superuser_irsa_role.name
  policy_arn = aws_iam_policy.superuser_policy.arn
}



# resource "aws_eks_pod_identity_association" "superuser" {
#   cluster_name    = data.terraform_remote_state.cluster.outputs.eks_name
#   namespace       = "kube-system"
#   service_account = "superuser-pod"
#   role_arn        = aws_iam_role.superuser_pod_role.arn
# }


# resource "kubernetes_service_account" "superuser" {
#   metadata {
#     name      = aws_eks_pod_identity_association.superuser.service_account
#     namespace = "kube-system"
#   }
# }

resource "kubernetes_service_account" "superuser_workloads" {
  metadata {
    name      = "superuser-pod"
    namespace = kubernetes_namespace.workloads.metadata[0].name
  }
}

resource "aws_eks_pod_identity_association" "superuser_workloads" {
  cluster_name    = data.terraform_remote_state.cluster.outputs.eks_name
  namespace       = kubernetes_namespace.workloads.metadata[0].name
  service_account = kubernetes_service_account.superuser_workloads.metadata[0].name
  role_arn        = aws_iam_role.superuser_pod_role.arn
}


resource "kubernetes_service_account" "superuser_irsa" {
  metadata {
    name      = "superuser-irsa"
    namespace = kubernetes_namespace.workloads.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.superuser_irsa_role.arn
    }
  }
}



############################################
# karpenter pod identity
############################################

# InstanceProfile Role


resource "aws_iam_role" "karpenter_instance_profile" {

  name = "KarpenterInstanceProfile"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "karpenter_ec2_instance_profile" {
  name = "KarpenterInstanceProfile"
  role = aws_iam_role.karpenter_instance_profile.name
}

# Attach Managed Policies to the Instance Profile Role
resource "aws_iam_role_policy_attachment" "karpenter_eks_worker_node" {
  role       = aws_iam_role.karpenter_instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_ec2_registry" {
  role       = aws_iam_role.karpenter_instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_ssm_core" {
  role       = aws_iam_role.karpenter_instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "karpenter_cni" {
  role       = aws_iam_role.karpenter_instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}




# Karpenter Controller Role
resource "aws_iam_role" "cluster_karpenter_role" {

  name = "ClusterKarpenterRole"

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

# Additional Policy for Karpenter-Specific Actions
resource "aws_iam_policy" "cluster_karpenter_policy" {
  name        = "KarpenterCustomPolicy"
  description = "Additional permissions for Karpenter"

  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "Karpenter"
      },
      {
        "Action" : "ec2:TerminateInstances",
        "Condition" : {
          "StringLike" : {
            "ec2:ResourceTag/karpenter.sh/nodepool" : "*"
          }
        },
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "ConditionalEC2Termination"
      },
      {
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterInstanceProfile",
        "Sid" : "PassNodeIAMRole"
      },
      {
        "Effect" : "Allow",
        "Action" : "eks:DescribeCluster",
        "Resource" : "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${data.terraform_remote_state.cluster.outputs.eks_name}",
        "Sid" : "EKSClusterEndpointLookup"
      },
      {
        "Sid" : "AllowScopedInstanceProfileCreationActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "iam:CreateInstanceProfile"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:RequestTag/kubernetes.io/cluster/${data.terraform_remote_state.cluster.outputs.eks_name}" : "owned",
            "aws:RequestTag/topology.kubernetes.io/region" : "${data.aws_region.current.name}"
          },
          "StringLike" : {
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" : "*"
          }
        }
      },
      {
        "Sid" : "AllowScopedInstanceProfileTagActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "iam:TagInstanceProfile"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/kubernetes.io/cluster/${data.terraform_remote_state.cluster.outputs.eks_name}" : "owned",
            "aws:ResourceTag/topology.kubernetes.io/region" : "${data.aws_region.current.name}",
            "aws:RequestTag/kubernetes.io/cluster/${data.terraform_remote_state.cluster.outputs.eks_name}" : "owned",
            "aws:RequestTag/topology.kubernetes.io/region" : "${data.aws_region.current.name}"
          },
          "StringLike" : {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" : "*",
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" : "*"
          }
        }
      },
      {
        "Sid" : "AllowScopedInstanceProfileActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/kubernetes.io/cluster/${data.terraform_remote_state.cluster.outputs.eks_name}" : "owned",
            "aws:ResourceTag/topology.kubernetes.io/region" : "${data.aws_region.current.name}"
          },
          "StringLike" : {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" : "*"
          }
        }
      },
      {
        "Sid" : "AllowInstanceProfileReadActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : "iam:GetInstanceProfile"
      }
    ],
    "Version" : "2012-10-17"
  })
}


resource "aws_iam_role_policy_attachment" "cluster_karpenter_policy_attachment" {
  role       = aws_iam_role.cluster_karpenter_role.name
  policy_arn = aws_iam_policy.cluster_karpenter_policy.arn
}



resource "aws_eks_pod_identity_association" "cluster_karpenter" {

  cluster_name    = data.terraform_remote_state.cluster.outputs.eks_name
  namespace       = "kube-system"
  service_account = "karpenter"
  role_arn        = aws_iam_role.cluster_karpenter_role.arn
}

resource "kubernetes_service_account" "cluster_karpenter" {
  metadata {
    name      = aws_eks_pod_identity_association.cluster_karpenter.service_account
    namespace = "kube-system"
  }
}
