#!/bin/sh

# Retrieve private and public subnet outputs from Terraform
PRIVATE_SUBNET_IDS=$(terraform output -json private_subnets | jq -r '.[]')
PUBLIC_SUBNET_IDS=$(terraform output -json public_subnets | jq -r '.[]')

# Retrieve private and public subnet configurations
PRIVATE_SUBNET_CONFIG=$(terraform output -json private_subnet_config)
PUBLIC_SUBNET_CONFIG=$(terraform output -json public_subnet_config)

# Function to tag subnets
tag_subnet() {
  local SUBNET_ID=$1
  local NAME_TAG=$2
  local ROLE_TAG=$3

  echo "Tagging subnet ${SUBNET_ID} with Name=${NAME_TAG}, Role=${ROLE_TAG}"
  aws ec2 create-tags --resources "${SUBNET_ID}" --tags \
    Key=Name,Value="${NAME_TAG}" \
    Key=kubernetes.io/role,Value="${ROLE_TAG}"
}

# Tag private subnets
for SUBNET_ID in ${PRIVATE_SUBNET_IDS}; do
  CIDR=$(aws ec2 describe-subnets --subnet-ids "${SUBNET_ID}" --query "Subnets[0].CidrBlock" --output text)
  NAME_TAG=$(echo "${PRIVATE_SUBNET_CONFIG}" | jq -r --arg CIDR "$CIDR" '.[$CIDR].name')
  ROLE_TAG=$(echo "${PRIVATE_SUBNET_CONFIG}" | jq -r --arg CIDR "$CIDR" '.[$CIDR].role')
  tag_subnet "${SUBNET_ID}" "${NAME_TAG}" "${ROLE_TAG}"
done

# Tag public subnets
for SUBNET_ID in ${PUBLIC_SUBNET_IDS}; do
  CIDR=$(aws ec2 describe-subnets --subnet-ids "${SUBNET_ID}" --query "Subnets[0].CidrBlock" --output text)
  NAME_TAG=$(echo "${PUBLIC_SUBNET_CONFIG}" | jq -r --arg CIDR "$CIDR" '.[$CIDR].name')
  ROLE_TAG=$(echo "${PUBLIC_SUBNET_CONFIG}" | jq -r --arg CIDR "$CIDR" '.[$CIDR].role')
  tag_subnet "${SUBNET_ID}" "${NAME_TAG}" "${ROLE_TAG}"
done

echo "All subnets have been tagged successfully."
