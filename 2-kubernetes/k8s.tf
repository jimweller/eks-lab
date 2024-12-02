resource "kubernetes_namespace" "crossplane" {
  metadata {
    name = "crossplane-system"
  }
}

resource "kubernetes_namespace" "workloads" {
  metadata {
    name = "workloads"
  }
}


############################################
# autoscaler pod identity
############################################

resource "aws_iam_role" "cluster_autoscaler_role" {

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
  role       = aws_iam_role.cluster_autoscaler_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {

  cluster_name    = data.terraform_remote_state.cluster.outputs.eks_name
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
# superuser pod identity
############################################

resource "aws_iam_role" "superuser_role" {

  name = "pod-role"

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
  role       = aws_iam_role.superuser_role.name
  policy_arn = aws_iam_policy.superuser_policy.arn
}

resource "aws_eks_pod_identity_association" "superuser" {
  cluster_name    = data.terraform_remote_state.cluster.outputs.eks_name
  namespace       = "crossplane-system"
  service_account = "pod-role"
  role_arn        = aws_iam_role.superuser_role.arn
}


resource "kubernetes_service_account" "superuser" {
  metadata {
    name      = aws_eks_pod_identity_association.superuser.service_account
    namespace = "crossplane-system"
  }
}
