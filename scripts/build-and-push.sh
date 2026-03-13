#!/bin/bash

# Script to build and push all Docker images to ECR
# Usage: ./build-and-push.sh [tag]

set -e

# Configuration
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
ECR_REPO_PREFIX="${ECR_REPO_PREFIX:-gs-}"
IMAGE_TAG="${1:-latest}"
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

ECR_REPO_FRONTEND="${ECR_REPO_PREFIX}streamingapp-frontend"
ECR_REPO_AUTH="${ECR_REPO_PREFIX}streamingapp-auth"
ECR_REPO_STREAMING="${ECR_REPO_PREFIX}streamingapp-streaming"
ECR_REPO_ADMIN="${ECR_REPO_PREFIX}streamingapp-admin"
ECR_REPO_CHAT="${ECR_REPO_PREFIX}streamingapp-chat"

echo "========================================="
echo "Building and Pushing StreamingApp Images"
echo "========================================="
echo "Registry: $ECR_REGISTRY"
echo "Repo Prefix: $ECR_REPO_PREFIX"
echo "Image Tag: $IMAGE_TAG"
echo "Git Commit: $GIT_COMMIT"
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REGISTRY"
echo ""

# Build and push frontend
echo "========================================="
echo "Building Frontend"
echo "========================================="
docker build \
    --build-arg REACT_APP_AUTH_API_URL=${REACT_APP_AUTH_API_URL:-"/api"} \
    --build-arg REACT_APP_STREAMING_API_URL=${REACT_APP_STREAMING_API_URL:-"/api"} \
    --build-arg REACT_APP_STREAMING_PUBLIC_URL=${REACT_APP_STREAMING_PUBLIC_URL:-""} \
    --build-arg REACT_APP_ADMIN_API_URL=${REACT_APP_ADMIN_API_URL:-"/api/admin"} \
    --build-arg REACT_APP_CHAT_API_URL=${REACT_APP_CHAT_API_URL:-"/api/chat"} \
    --build-arg REACT_APP_CHAT_SOCKET_URL=${REACT_APP_CHAT_SOCKET_URL:-""} \
    -t "$ECR_REGISTRY/$ECR_REPO_FRONTEND:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/$ECR_REPO_FRONTEND:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/$ECR_REPO_FRONTEND:latest" \
    ./frontend

echo "Pushing frontend images..."
docker push "$ECR_REGISTRY/$ECR_REPO_FRONTEND:$IMAGE_TAG"
docker push "$ECR_REGISTRY/$ECR_REPO_FRONTEND:$GIT_COMMIT"
docker push "$ECR_REGISTRY/$ECR_REPO_FRONTEND:latest"
echo "✓ Frontend pushed successfully"
echo ""

# Build and push auth service
echo "========================================="
echo "Building Auth Service"
echo "========================================="
docker build \
    -t "$ECR_REGISTRY/$ECR_REPO_AUTH:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/$ECR_REPO_AUTH:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/$ECR_REPO_AUTH:latest" \
    ./backend/authService

echo "Pushing auth service images..."
docker push "$ECR_REGISTRY/$ECR_REPO_AUTH:$IMAGE_TAG"
docker push "$ECR_REGISTRY/$ECR_REPO_AUTH:$GIT_COMMIT"
docker push "$ECR_REGISTRY/$ECR_REPO_AUTH:latest"
echo "✓ Auth service pushed successfully"
echo ""

# Build and push streaming service
echo "========================================="
echo "Building Streaming Service"
echo "========================================="
docker build \
    -f backend/streamingService/Dockerfile \
    -t "$ECR_REGISTRY/$ECR_REPO_STREAMING:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/$ECR_REPO_STREAMING:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/$ECR_REPO_STREAMING:latest" \
    ./backend

echo "Pushing streaming service images..."
docker push "$ECR_REGISTRY/$ECR_REPO_STREAMING:$IMAGE_TAG"
docker push "$ECR_REGISTRY/$ECR_REPO_STREAMING:$GIT_COMMIT"
docker push "$ECR_REGISTRY/$ECR_REPO_STREAMING:latest"
echo "✓ Streaming service pushed successfully"
echo ""

# Build and push admin service
echo "========================================="
echo "Building Admin Service"
echo "========================================="
docker build \
    -f backend/adminService/Dockerfile \
    -t "$ECR_REGISTRY/$ECR_REPO_ADMIN:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/$ECR_REPO_ADMIN:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/$ECR_REPO_ADMIN:latest" \
    ./backend

echo "Pushing admin service images..."
docker push "$ECR_REGISTRY/$ECR_REPO_ADMIN:$IMAGE_TAG"
docker push "$ECR_REGISTRY/$ECR_REPO_ADMIN:$GIT_COMMIT"
docker push "$ECR_REGISTRY/$ECR_REPO_ADMIN:latest"
echo "✓ Admin service pushed successfully"
echo ""

# Build and push chat service
echo "========================================="
echo "Building Chat Service"
echo "========================================="
docker build \
    -f backend/chatService/Dockerfile \
    -t "$ECR_REGISTRY/$ECR_REPO_CHAT:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/$ECR_REPO_CHAT:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/$ECR_REPO_CHAT:latest" \
    ./backend

echo "Pushing chat service images..."
docker push "$ECR_REGISTRY/$ECR_REPO_CHAT:$IMAGE_TAG"
docker push "$ECR_REGISTRY/$ECR_REPO_CHAT:$GIT_COMMIT"
docker push "$ECR_REGISTRY/$ECR_REPO_CHAT:latest"
echo "✓ Chat service pushed successfully"
echo ""

echo "========================================="
echo "All Images Built and Pushed Successfully"
echo "========================================="
echo ""
echo "Images pushed with tags:"
echo "  - $IMAGE_TAG"
echo "  - $GIT_COMMIT"
echo "  - latest"
echo ""
echo "Next steps:"
echo "  1. Deploy to EKS using: ./scripts/deploy-to-eks.sh"
echo "  2. Or use Helm: helm upgrade --install streamingapp ./k8s/helm/streamingapp"
