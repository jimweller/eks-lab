#!/bin/bash

# Fetch Terraform outputs
PRIVATE_SUBNETS=$(tofu output -json private_subnets | jq -r '.[]')
PUBLIC_SUBNETS=$(tofu output -json public_subnets | jq -r '.[]')
PRIVATE_CONFIG=$(tofu output -json private_subnet_config)
PUBLIC_CONFIG=$(tofu output -json public_subnet_config)
EKS_SECURITY_GROUP=$(tofu output -raw eks_security_group)
CLUSTER_NAME=$(tofu output -raw eks_name)


# Function to dynamically collect tags
collect_tags() {
  local config=$1
  local cidr=$2
  local tags=""

  # Extract all tags for the given CIDR
  for key in $(echo "$config" | jq -r ".[\"$cidr\"] | keys_unsorted[]"); do
    # Access key and value using fully quoted key
    value=$(echo "$config" | jq -r ".[\"$cidr\"][\"$key\"] // empty")
    if [[ -n "$value" ]]; then
      tags="$tags Key=$key,Value=$value"
    fi
  done

  echo "$tags"
}

# Function to apply tags dynamically
apply_tags() {
  local subnet=$1
  local tags=$2

  if [[ -z "$tags" ]]; then
    echo "Skipping subnet $subnet due to missing tags."
    return
  fi

  echo "Tagging subnet $subnet with tags: $tags"
  aws ec2 create-tags --resources "$subnet" --tags $tags
}

# Tag private subnets
echo "Tagging private subnets..."
for SUBNET in $PRIVATE_SUBNETS; do
  CIDR=$(aws ec2 describe-subnets --subnet-ids "$SUBNET" --query 'Subnets[0].CidrBlock' --output text)
  TAGS=$(collect_tags "$PRIVATE_CONFIG" "$CIDR")
  apply_tags "$SUBNET" "$TAGS"
done

# Tag public subnets
echo "Tagging public subnets..."
for SUBNET in $PUBLIC_SUBNETS; do
  CIDR=$(aws ec2 describe-subnets --subnet-ids "$SUBNET" --query 'Subnets[0].CidrBlock' --output text)
  TAGS=$(collect_tags "$PUBLIC_CONFIG" "$CIDR")
  apply_tags "$SUBNET" "$TAGS"
done


# Tag EKS Security Group for Karpenter
echo "Tagging security group $EKS_SECURITY_GROUP with karpenter.sh/discovery=${CLUSTER_NAME}"
aws ec2 create-tags \
    --resources "$EKS_SECURITY_GROUP" \
    --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}"