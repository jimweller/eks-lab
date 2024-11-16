# EKS Lab

configure kubectl for aws

aws eks update-kubeconfig --region us-west-2 --name dev-eks-cluster

~$3/day or ~$90/mo

k get events --sort-by='.lastTimestamp' --namespace=default --since=5m
k get events --sort-by='.lastTimestamp' --namespace=kube-system --since=5m
