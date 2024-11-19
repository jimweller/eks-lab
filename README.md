# EKS Lab

configure kubectl for aws

aws eks update-kubeconfig --region us-west-2 --name dev-eks-cluster

~$3/day or ~$90/mo

k get events --sort-by='.lastTimestamp' --namespace=default --since=5m
k get events --sort-by='.lastTimestamp' --namespace=kube-system --since=5m

Subnet Plan

```markdown
+---------+---------------+---------------+---------------+---------------+
| Account |   Private 1   |   Private 2   |   Public 1    |   Public 2    |
+---------+---------------+---------------+---------------+---------------+
| Control | 10.0.8.0/24   | 10.0.88.0/24  | 10.0.108.0/24 | 10.0.188.0/24 |
| Cluster | 10.0.9.0/24   | 10.0.99.0/24  | 10.0.109.0/24 | 10.0.199.0/24 |
| Work1   | 10.0.1.0/24   | 10.0.10.0/24  | 10.0.101.0/24 | 10.0.110.0/24 |
| Work2   | 10.0.2.0/24   | 10.0.20.0/24  | 10.0.102.0/24 | 10.0.120.0/24 |
+---------+---------------+---------------+---------------+---------------+
```
