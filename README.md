# Kubernetes EKS Lab and Playground

This repo is a playground for kubernetes and EKS. The overall intent is to
illustrate a kubernetes architecture that can be used by a platform engineering
team that serves teams of software engineers. Dev teams would have their k8s
workloads in a centralized cluster AWS account. They would then have their own
AWS accounts to provision AWS resources. IAM roles and EKS pod identities allow
cross account access from workloads to AWS resources. Crossplane allows dev
teams to use k8s manifests or helm files to deploy resources to their accounts
using kubernetes and potentially leveraging custom compositions built by the
platform team.

It includes

- Three AWS accounts
  - The cluster account for kubernetes
  - work1 and work2 to represent teams of devs' accounts
  - VPC that is RAM shared between accounts
- EKS kubernetes cluster
  - single node group for core system services
  - nodepool (karpenter) for workloads
  - Spot graviton instances (inexpensive)
- Kubernetes configuration for aws pod identities
- Metrics server
- Karpenter for autoscaling nodes for workloads
- Crossplane
  - ProviderConfigs with IAM permissions for the work1 and work2 accounts
  - Helm charts to deploy resources from crossplane to the work acounts
- Cross account webserver from composition and helm chart
  - deployment in the cluster uses an init container and assume role to copy a file from a work account s3 buck to the nginx container to serve

## AWS Account Overview

![arch1](architecture1.drawio.svg)

## Kubernetes and Crossplane Overview

![arch2](architecture2.drawio.svg)

