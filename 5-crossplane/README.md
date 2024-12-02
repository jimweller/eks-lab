helm repo add crossplane-stable https://charts.crossplane.io/stable

helm repo update

helm pull crossplane-stable/crossplane --untar

- change nodeSelectors and/or tolerations

helm install crossplane ./crossplane \
--namespace crossplane-system \
--create-namespace

kaf 1providers.yml

kaf 2providerconfigs.yaml