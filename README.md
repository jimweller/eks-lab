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


## Notes

Merge kube config files, like ~/.kube/config and one downloaded from rancher

```bash
export KUBECONFIG=~/.kube/config:/path/cluster1:/path/cluster2
k config view --flatten > all-in-one-kubeconfig.yaml
```

<https://able8.medium.com/how-to-merge-multiple-kubeconfig-files-into-one-36fc987c2e2f>

Change cluster and namespace

```bash
k config set-cluster CLUSTER --namespace NAMESPACE
```

Change namespaces in current cluster

```bash
k config set-context --current --namespace NAMESPACE
```

Helm install/upgrade

```bash
helm RELEASE ./somefile.yml --install -f ./some/override
```

List available types/resources

```bash
kubectl api-resources -o wide
```

Get helm release (aka chart)

```bash
helm get all <release-name> --namespace <namespace>
```

List releases (depending on permissions, might need to use --namespace)

```bash
helm list --all-namespaces
```

Handy commands to check on a resource deploy/install

```bash
helm status RELEASE
kubectl get all
kubectl describe SOMETYPE_FROM_API_RESOURCES
kubectl get events --sort-by=.lastTimestamp
```


