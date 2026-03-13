#!/bin/bash

# Script to build and push all Docker images to ECR
# Usage: ./build-and-push.sh [tag]

set -e

# Configuration
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
IMAGE_TAG="${1:-latest}"
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "========================================="
echo "Building and Pushing StreamingApp Images"
echo "========================================="
echo "Registry: $ECR_REGISTRY"
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
    --build-arg REACT_APP_AUTH_API_URL=${REACT_APP_AUTH_API_URL:-"http://localhost:3001/api"} \
    --build-arg REACT_APP_STREAMING_API_URL=${REACT_APP_STREAMING_API_URL:-"http://localhost:3002/api"} \
    --build-arg REACT_APP_STREAMING_PUBLIC_URL=${REACT_APP_STREAMING_PUBLIC_URL:-"http://localhost:3002"} \
    --build-arg REACT_APP_ADMIN_API_URL=${REACT_APP_ADMIN_API_URL:-"http://localhost:3003/api/admin"} \
    --build-arg REACT_APP_CHAT_API_URL=${REACT_APP_CHAT_API_URL:-"http://localhost:3004/api/chat"} \
    --build-arg REACT_APP_CHAT_SOCKET_URL=${REACT_APP_CHAT_SOCKET_URL:-"http://localhost:3004"} \
    -t "$ECR_REGISTRY/streamingapp-frontend:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/streamingapp-frontend:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/streamingapp-frontend:latest" \
    ./frontend

echo "Pushing frontend images..."
docker push "$ECR_REGISTRY/streamingapp-frontend:$IMAGE_TAG"
docker push "$ECR_REGISTRY/streamingapp-frontend:$GIT_COMMIT"
docker push "$ECR_REGISTRY/streamingapp-frontend:latest"
echo "✓ Frontend pushed successfully"
echo ""

# Build and push auth service
echo "========================================="
echo "Building Auth Service"
echo "========================================="
docker build \
    -t "$ECR_REGISTRY/streamingapp-auth:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/streamingapp-auth:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/streamingapp-auth:latest" \
    ./backend/authService

echo "Pushing auth service images..."
docker push "$ECR_REGISTRY/streamingapp-auth:$IMAGE_TAG"
docker push "$ECR_REGISTRY/streamingapp-auth:$GIT_COMMIT"
docker push "$ECR_REGISTRY/streamingapp-auth:latest"
echo "✓ Auth service pushed successfully"
echo ""

# Build and push streaming service
echo "========================================="
echo "Building Streaming Service"
echo "========================================="
docker build \
    -f backend/streamingService/Dockerfile \
    -t "$ECR_REGISTRY/streamingapp-streaming:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/streamingapp-streaming:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/streamingapp-streaming:latest" \
    ./backend

echo "Pushing streaming service images..."
docker push "$ECR_REGISTRY/streamingapp-streaming:$IMAGE_TAG"
docker push "$ECR_REGISTRY/streamingapp-streaming:$GIT_COMMIT"
docker push "$ECR_REGISTRY/streamingapp-streaming:latest"
echo "✓ Streaming service pushed successfully"
echo ""

# Build and push admin service
echo "========================================="
echo "Building Admin Service"
echo "========================================="
docker build \
    -f backend/adminService/Dockerfile \
    -t "$ECR_REGISTRY/streamingapp-admin:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/streamingapp-admin:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/streamingapp-admin:latest" \
    ./backend

echo "Pushing admin service images..."
docker push "$ECR_REGISTRY/streamingapp-admin:$IMAGE_TAG"
docker push "$ECR_REGISTRY/streamingapp-admin:$GIT_COMMIT"
docker push "$ECR_REGISTRY/streamingapp-admin:latest"
echo "✓ Admin service pushed successfully"
echo ""

# Build and push chat service
echo "========================================="
echo "Building Chat Service"
echo "========================================="
docker build \
    -f backend/chatService/Dockerfile \
    -t "$ECR_REGISTRY/streamingapp-chat:$IMAGE_TAG" \
    -t "$ECR_REGISTRY/streamingapp-chat:$GIT_COMMIT" \
    -t "$ECR_REGISTRY/streamingapp-chat:latest" \
    ./backend

echo "Pushing chat service images..."
docker push "$ECR_REGISTRY/streamingapp-chat:$IMAGE_TAG"
docker push "$ECR_REGISTRY/streamingapp-chat:$GIT_COMMIT"
docker push "$ECR_REGISTRY/streamingapp-chat:latest"
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
