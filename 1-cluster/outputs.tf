output "kubectx_command" {
  value = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${module.eks.cluster_name}"
}

output "eks_name" {
  value = module.eks.cluster_name
}

output "eks_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_certificate" {
  value = module.eks.cluster_certificate_authority_data
  sensitive = true
}



output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}


output "private_subnet_config" {
  value = local.private_subnet_config
}

output "public_subnet_config" {
  value = local.public_subnet_config
}

