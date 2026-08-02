#!/bin/bash

# One time script to setup the S3 bucket for the Terraform backend
# Locking enabled by default with no DynamoDB table (requires Terraform 1.10+)

set -euo pipefail

REGION=eu-central-1
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="terraform-state-${ACCOUNT_ID}-${REGION}"

echo "Region: ${REGION}"
echo "Account ID: ${ACCOUNT_ID}"
echo "Bucket Name: ${BUCKET_NAME}"
echo ""

echo "Creating S3 bucket..."
aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${REGION} --create-bucket-configuration LocationConstraint=${REGION}
aws s3api put-bucket-versioning --bucket ${BUCKET_NAME} --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket ${BUCKET_NAME} --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket ${BUCKET_NAME} --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Bucket created successfully"
echo ""
echo "In order to initialize the Terraform backend, switch to the environment directory and run the following command:"
echo "terraform init -backend-config=\"bucket=${BUCKET_NAME}\" -backend-config=\"region=${REGION}\""