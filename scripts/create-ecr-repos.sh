#!/bin/bash

# Script to create ECR repositories for StreamingApp
# Run this script before pushing images to ECR

set -e

# Configuration
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO_PREFIX="${ECR_REPO_PREFIX:-gs-}"

# Repository names
REPOS=(
    "${ECR_REPO_PREFIX}streamingapp-frontend"
    "${ECR_REPO_PREFIX}streamingapp-auth"
    "${ECR_REPO_PREFIX}streamingapp-streaming"
    "${ECR_REPO_PREFIX}streamingapp-admin"
    "${ECR_REPO_PREFIX}streamingapp-chat"
)

echo "========================================="
echo "Creating ECR Repositories"
echo "========================================="
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "Repo Prefix: $ECR_REPO_PREFIX"
echo ""

# Create each repository
for REPO in "${REPOS[@]}"; do
    echo "Creating repository: $REPO"
    
    aws ecr create-repository \
        --repository-name "$REPO" \
        --region "$AWS_REGION" \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256 \
        2>/dev/null || echo "Repository $REPO already exists"
    
    # Set lifecycle policy to keep only last 10 images
    aws ecr put-lifecycle-policy \
        --repository-name "$REPO" \
        --region "$AWS_REGION" \
        --lifecycle-policy-text '{
            "rules": [
                {
                    "rulePriority": 1,
                    "description": "Keep only last 10 images",
                    "selection": {
                        "tagStatus": "any",
                        "countType": "imageCountMoreThan",
                        "countNumber": 10
                    },
                    "action": {
                        "type": "expire"
                    }
                }
            ]
        }' || echo "Failed to set lifecycle policy for $REPO"
    
    echo "✓ Repository $REPO configured"
    echo ""
done

echo "========================================="
echo "ECR Repositories Created Successfully"
echo "========================================="
echo ""
echo "Repository URLs:"
for REPO in "${REPOS[@]}"; do
    echo "  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO"
done
echo ""
echo "To login to ECR, run:"
echo "  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
