#!/bin/bash

# Script to deploy StreamingApp to EKS using Helm
# Usage: ./deploy-to-eks.sh [environment] [image-tag]

set -e

# Configuration
ENVIRONMENT="${1:-dev}"
IMAGE_TAG="${2:-latest}"
CLUSTER_NAME="${CLUSTER_NAME:-streamingapp-cluster}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
ECR_REPO_PREFIX="${ECR_REPO_PREFIX:-gs-}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

echo "========================================="
echo "Deploying StreamingApp to EKS"
echo "========================================="
echo "Environment: $ENVIRONMENT"
echo "Image Tag: $IMAGE_TAG"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo "Repo Prefix: $ECR_REPO_PREFIX"
echo ""

# Update kubeconfig
echo "Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
echo ""

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
kubectl cluster-info
echo ""

# Create namespace if it doesn't exist
echo "Ensuring namespace exists..."
kubectl create namespace "$ENVIRONMENT" --dry-run=client -o yaml | kubectl apply -f -
echo ""

# Create or update secrets
echo "Creating secrets..."
read -p "Enter JWT_SECRET (or press Enter to use default): " JWT_SECRET
JWT_SECRET=${JWT_SECRET:-"changeme-$(openssl rand -hex 32)"}

read -p "Enter AWS_ACCESS_KEY_ID (or press Enter to skip): " AWS_ACCESS_KEY_ID
read -sp "Enter AWS_SECRET_ACCESS_KEY (or press Enter to skip): " AWS_SECRET_ACCESS_KEY
echo ""
read -p "Enter AWS_S3_BUCKET (or press Enter to skip): " AWS_S3_BUCKET
read -p "Enter AWS_CDN_URL (or press Enter to skip): " AWS_CDN_URL

# Deploy using Helm
echo ""
echo "Deploying application with Helm..."
helm upgrade --install streamingapp ./k8s/helm/streamingapp \
  --namespace "$ENVIRONMENT" \
  --create-namespace \
  --set imageRegistry.url="$ECR_REGISTRY" \
  --set imageTag="$IMAGE_TAG" \
  --set frontend.image.repository="${ECR_REPO_PREFIX}streamingapp-frontend" \
  --set auth.image.repository="${ECR_REPO_PREFIX}streamingapp-auth" \
  --set streaming.image.repository="${ECR_REPO_PREFIX}streamingapp-streaming" \
  --set admin.image.repository="${ECR_REPO_PREFIX}streamingapp-admin" \
  --set chat.image.repository="${ECR_REPO_PREFIX}streamingapp-chat" \
  --set global.environment="$ENVIRONMENT" \
  --set secrets.jwtSecret="$JWT_SECRET" \
  --set secrets.awsAccessKeyId="$AWS_ACCESS_KEY_ID" \
  --set secrets.awsSecretAccessKey="$AWS_SECRET_ACCESS_KEY" \
  --set secrets.awsS3Bucket="$AWS_S3_BUCKET" \
  --set secrets.awsCdnUrl="$AWS_CDN_URL" \
  --wait \
  --timeout 10m

echo ""
echo "✓ Deployment complete!"
echo ""

# Check deployment status
echo "========================================="
echo "Deployment Status"
echo "========================================="
kubectl get deployments -n "$ENVIRONMENT"
echo ""

echo "========================================="
echo "Pod Status"
echo "========================================="
kubectl get pods -n "$ENVIRONMENT"
echo ""

echo "========================================="
echo "Services"
echo "========================================="
kubectl get services -n "$ENVIRONMENT"
echo ""

# Get Load Balancer URL
echo "Waiting for Load Balancer to be ready..."
sleep 10

FRONTEND_LB=$(kubectl get service -n "$ENVIRONMENT" -o jsonpath='{.items[?(@.metadata.name=="streamingapp-frontend")].status.loadBalancer.ingress[0].hostname}')

if [ -n "$FRONTEND_LB" ]; then
    echo ""
    echo "========================================="
    echo "Application URLs"
    echo "========================================="
    echo "Frontend: http://$FRONTEND_LB"
    echo ""
else
    echo ""
    echo "Load Balancer is still provisioning. Check later with:"
    echo "  kubectl get svc -n $ENVIRONMENT"
    echo ""
fi

# Show logs
echo "To view logs, run:"
echo "  kubectl logs -f deployment/streamingapp-frontend -n $ENVIRONMENT"
echo "  kubectl logs -f deployment/streamingapp-auth -n $ENVIRONMENT"
echo ""

echo "To scale deployments, run:"
echo "  kubectl scale deployment/streamingapp-frontend --replicas=5 -n $ENVIRONMENT"
echo ""

echo "To delete the deployment, run:"
echo "  helm uninstall streamingapp -n $ENVIRONMENT"
