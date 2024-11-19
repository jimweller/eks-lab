output "eks_cluster_endpoint" {
  value       = module.eks.cluster_endpoint
}

output "kubectx_command" {
  value = "aws eks update-kubeconfig --region ${data.aws_region.dev.name} --name ${module.eks.cluster_name}"
}

